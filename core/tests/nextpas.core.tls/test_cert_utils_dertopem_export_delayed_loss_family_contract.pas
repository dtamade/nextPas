program test_cert_utils_dertopem_export_delayed_loss_family_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes, ctypes,
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
  TD2IX509StubMode = (
    dsmNone,
    dsmDisableBIOSMemAfterDecodeSuccess
  );

  TBIOSMemStubMode = (
    bsmNone,
    bsmDisableBIONewBeforeExportConstructor
  );

  TBIONewStubMode = (
    bnmNone,
    bnmDisablePEMWriteAfterExportConstructor
  );

  TPrepareScenario = procedure;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalD2IX509: Td2i_X509 = nil;
  GOriginalBIOSMem: TBIO_s_mem = nil;
  GOriginalBIONew: TBIO_new = nil;
  GOriginalPEMWriteX509: TPEM_write_bio_X509 = nil;
  GD2IX509StubMode: TD2IX509StubMode = dsmNone;
  GBIOSMemStubMode: TBIOSMemStubMode = bsmNone;
  GBIONewStubMode: TBIONewStubMode = bnmNone;

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

procedure WarmupDERToPEMMaterial(out ADER: TBytes; out APEM: string);
var
  LFixturePEM: string;
begin
  LFixturePEM := LoadFixturePEM;
  if LFixturePEM = '' then
    raise Exception.Create('certificate fixture is empty');

  ADER := TCertificateUtils.PEMToDER(LFixturePEM);
  if Length(ADER) = 0 then
    raise Exception.Create('failed to warm up PEMToDER fixture');

  APEM := TCertificateUtils.DERToPEM(ADER);
  if APEM = '' then
    raise Exception.Create('failed to warm up DERToPEM');
end;

procedure ResetStubState;
begin
  GD2IX509StubMode := dsmNone;
  GBIOSMemStubMode := bsmNone;
  GBIONewStubMode := bnmNone;
end;

procedure RestoreHelperFunctions;
begin
  d2i_X509 := GOriginalD2IX509;
  BIO_s_mem := GOriginalBIOSMem;
  BIO_new := GOriginalBIONew;
  PEM_write_bio_X509 := GOriginalPEMWriteX509;
  ResetStubState;
end;

function StubD2IX509(a: PPX509; const AIn: PPByte; len: clong): PX509; cdecl;
begin
  if Assigned(GOriginalD2IX509) then
    Result := GOriginalD2IX509(a, AIn, len)
  else
    Result := nil;

  if (GD2IX509StubMode = dsmDisableBIOSMemAfterDecodeSuccess) and (Result <> nil) then
    BIO_s_mem := nil;
end;

function StubBIOSMem: PBIO_METHOD; cdecl;
begin
  if Assigned(GOriginalBIOSMem) then
    Result := GOriginalBIOSMem()
  else
    Result := nil;

  if GBIOSMemStubMode = bsmDisableBIONewBeforeExportConstructor then
    BIO_new := nil;
end;

function StubBIONew(const AType: PBIO_METHOD): PBIO; cdecl;
begin
  if Assigned(GOriginalBIONew) then
    Result := GOriginalBIONew(AType)
  else
    Result := nil;

  if (GBIONewStubMode = bnmDisablePEMWriteAfterExportConstructor) and (Result <> nil) then
    PEM_write_bio_X509 := nil;
end;

procedure PrepareDERToPEMBIOSMemFailure;
begin
  RestoreHelperFunctions;
  d2i_X509 := @StubD2IX509;
  GD2IX509StubMode := dsmDisableBIOSMemAfterDecodeSuccess;
end;

procedure PrepareDERToPEMBIONewFailure;
begin
  RestoreHelperFunctions;
  BIO_s_mem := @StubBIOSMem;
  GBIOSMemStubMode := bsmDisableBIONewBeforeExportConstructor;
end;

procedure PrepareDERToPEMWriteFailure;
begin
  RestoreHelperFunctions;
  BIO_new := @StubBIONew;
  GBIONewStubMode := bnmDisablePEMWriteAfterExportConstructor;
end;

procedure AssertDERToPEMSafeDegrade(
  const AName: string;
  const ADERFixture: TBytes;
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
  LResult := 'sentinel';
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
  LTryPEM := 'sentinel';
  if Assigned(APrepareScenario) then
    APrepareScenario();
  try
    LTryResult := TCertificateUtils.TryDERToPEM(ADERFixture, LTryPEM);
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
      LTryResult := True;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should return empty string', LResult = '',
    'expected DERToPEM to preserve its empty-string contract');
  AssertTrue(AName + ' Try wrapper should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' Try wrapper should return False', not LTryResult,
    'expected TryDERToPEM to return False');
  AssertTrue(AName + ' Try wrapper should clear output', LTryPEM = '',
    'expected TryDERToPEM output to be empty');
end;

procedure TestDERToPEMShouldDegradeSafelyWhenExportHelpersDisappearAfterDecode;
var
  LFixtureDER: TBytes;
  LFixturePEM: string;
begin
  WriteLn;
  WriteLn('=== Certificate utils DERToPEM export delayed-loss family ===');

  if (not Assigned(d2i_X509)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(BIO_new)) or
     (not Assigned(PEM_write_bio_X509)) or
     (not Assigned(BIO_free)) then
  begin
    MarkSkip('certificate utils DERToPEM export delayed-loss family',
      'required baseline OpenSSL X509/BIO/PEM helpers are unavailable');
    Exit;
  end;

  WarmupDERToPEMMaterial(LFixtureDER, LFixturePEM);
  if LFixturePEM = '' then
    raise Exception.Create('warmup PEM unexpectedly empty');

  GOriginalD2IX509 := d2i_X509;
  GOriginalBIOSMem := BIO_s_mem;
  GOriginalBIONew := BIO_new;
  GOriginalPEMWriteX509 := PEM_write_bio_X509;

  AssertDERToPEMSafeDegrade(
    'DERToPEM when BIO_s_mem disappears after decode success',
    LFixtureDER,
    @PrepareDERToPEMBIOSMemFailure
  );

  AssertDERToPEMSafeDegrade(
    'DERToPEM when BIO_new disappears after BIO_s_mem success',
    LFixtureDER,
    @PrepareDERToPEMBIONewFailure
  );

  AssertDERToPEMSafeDegrade(
    'DERToPEM when PEM_write_bio_X509 disappears after export constructor success',
    LFixtureDER,
    @PrepareDERToPEMWriteFailure
  );

  RestoreHelperFunctions;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils DERToPEM Export Delayed-Loss Family Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils DERToPEM export delayed-loss family',
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
      TestDERToPEMShouldDegradeSafelyWhenExportHelpersDisappearAfterDecode;

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
      RestoreHelperFunctions;
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
