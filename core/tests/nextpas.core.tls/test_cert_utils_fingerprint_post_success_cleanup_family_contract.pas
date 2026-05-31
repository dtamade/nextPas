program test_cert_utils_fingerprint_post_success_cleanup_family_contract;

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

const
  CERT_FIXTURE_PATH = 'tests/certificate/test_certs/signer_cert.pem';

type
  TX509DigestStubMode = (
    xdmNone,
    xdmDisableX509FreeAfterDigestSuccess
  );

  TX509FreeStubMode = (
    xfmNone,
    xfmDisableBIOFreeAfterCleanup
  );

  TX509DigestFunc = function(const data: Pointer; const &type: Pointer; md: PByte; len: PCardinal): Integer; cdecl;
  TPrepareScenario = procedure;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalX509Digest: TX509DigestFunc = nil;
  GOriginalX509Free: TX509_free = nil;
  GOriginalBIOFree: TBIO_free = nil;
  GX509DigestStubMode: TX509DigestStubMode = xdmNone;
  GX509FreeStubMode: TX509FreeStubMode = xfmNone;

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

procedure WarmupFingerprintMaterial(out APEM: string; out AFingerprint: string);
begin
  APEM := LoadFixturePEM;
  if APEM = '' then
    raise Exception.Create('certificate fixture is empty');

  AFingerprint := TCertificateUtils.GetFingerprint(APEM);
  if AFingerprint = '' then
    raise Exception.Create('failed to warm up GetFingerprint');
end;

procedure ResetStubState;
begin
  GX509DigestStubMode := xdmNone;
  GX509FreeStubMode := xfmNone;
end;

procedure RestoreHelperFunctions(
  AOriginalX509Digest: TX509DigestFunc;
  AOriginalX509Free: TX509_free;
  AOriginalBIOFree: TBIO_free
);
begin
  X509_digest := AOriginalX509Digest;
  X509_free := AOriginalX509Free;
  BIO_free := AOriginalBIOFree;
  ResetStubState;
end;

function StubX509Digest(const data: Pointer; const &type: Pointer; md: PByte; len: PCardinal): Integer; cdecl;
begin
  if Assigned(GOriginalX509Digest) then
    Result := GOriginalX509Digest(data, &type, md, len)
  else
    Result := 0;

  if (GX509DigestStubMode = xdmDisableX509FreeAfterDigestSuccess) and (Result = 1) then
    X509_free := nil;
end;

procedure StubX509Free(x: PX509); cdecl;
begin
  if Assigned(GOriginalX509Free) then
    GOriginalX509Free(x);

  if GX509FreeStubMode = xfmDisableBIOFreeAfterCleanup then
    BIO_free := nil;
end;

procedure PrepareX509CleanupFailure;
begin
  ResetStubState;
  X509_free := GOriginalX509Free;
  BIO_free := GOriginalBIOFree;
  X509_digest := @StubX509Digest;
  GX509DigestStubMode := xdmDisableX509FreeAfterDigestSuccess;
end;

procedure PrepareBIOCleanupFailure;
begin
  ResetStubState;
  X509_digest := GOriginalX509Digest;
  BIO_free := GOriginalBIOFree;
  X509_free := @StubX509Free;
  GX509FreeStubMode := xfmDisableBIOFreeAfterCleanup;
end;

procedure AssertFingerprintPreservesOutput(
  const AName: string;
  const APEM: string;
  const AExpectedFingerprint: string;
  APrepareScenario: TPrepareScenario
);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
  LTryFingerprint: string;
begin
  LRaised := False;
  LDetail := '';
  LResult := '';
  if Assigned(APrepareScenario) then
    APrepareScenario();
  try
    LResult := TCertificateUtils.GetFingerprint(APEM);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  LTryRaised := False;
  LTryDetail := '';
  LTryFingerprint := '';
  if Assigned(APrepareScenario) then
    APrepareScenario();
  try
    LTryResult := TCertificateUtils.TryGetFingerprint(APEM, LTryFingerprint);
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
      LTryResult := False;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should preserve fingerprint output', LResult = AExpectedFingerprint,
    'expected GetFingerprint to keep the already-materialized fingerprint');
  AssertTrue(AName + ' Try wrapper should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' Try wrapper should return True', LTryResult,
    'expected TryGetFingerprint to preserve the successful direct result');
  AssertTrue(AName + ' Try wrapper should preserve fingerprint output', LTryFingerprint = AExpectedFingerprint,
    'expected TryGetFingerprint output to match the preserved fingerprint');
end;

procedure TestFingerprintPostSuccessCleanupFamily;
var
  LFixturePEM: string;
  LExpectedFingerprint: string;
  LOriginalX509Digest: TX509DigestFunc;
  LOriginalX509Free: TX509_free;
  LOriginalBIOFree: TBIO_free;
begin
  WriteLn;
  WriteLn('=== Certificate utils fingerprint post-success cleanup family ===');

  if (not Assigned(BIO_new_mem_buf)) or
     (not Assigned(PEM_read_bio_X509)) or
     (not Assigned(BIO_free)) or
     (not Assigned(X509_digest)) or
     (not Assigned(EVP_sha256)) or
     (not Assigned(X509_free)) then
  begin
    MarkSkip('certificate utils fingerprint post-success cleanup family contract',
      'required baseline OpenSSL BIO/PEM/X509/EVP helpers are unavailable');
    Exit;
  end;

  WarmupFingerprintMaterial(LFixturePEM, LExpectedFingerprint);

  LOriginalX509Digest := X509_digest;
  LOriginalX509Free := X509_free;
  LOriginalBIOFree := BIO_free;

  GOriginalX509Digest := LOriginalX509Digest;
  GOriginalX509Free := LOriginalX509Free;
  GOriginalBIOFree := LOriginalBIOFree;

  try
    AssertFingerprintPreservesOutput(
      'GetFingerprint when X509_free becomes unavailable after digest success',
      LFixturePEM,
      LExpectedFingerprint,
      @PrepareX509CleanupFailure
    );
    RestoreHelperFunctions(
      LOriginalX509Digest,
      LOriginalX509Free,
      LOriginalBIOFree
    );

    AssertFingerprintPreservesOutput(
      'GetFingerprint when BIO_free becomes unavailable after certificate cleanup success',
      LFixturePEM,
      LExpectedFingerprint,
      @PrepareBIOCleanupFailure
    );
  finally
    RestoreHelperFunctions(
      LOriginalX509Digest,
      LOriginalX509Free,
      LOriginalBIOFree
    );
    GOriginalX509Digest := nil;
    GOriginalX509Free := nil;
    GOriginalBIOFree := nil;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils Fingerprint Post-Success Cleanup Family Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils fingerprint post-success cleanup family contract',
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
      TestFingerprintPostSuccessCleanupFamily;

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
