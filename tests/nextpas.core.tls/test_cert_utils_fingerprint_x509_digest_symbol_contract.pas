program test_cert_utils_fingerprint_x509_digest_symbol_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
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

const
  CERT_FIXTURE_PATH = 'tests/certificate/test_certs/signer_cert.pem';

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;

type
  TX509DigestFunc = function(const data: Pointer; const &type: Pointer; md: PByte; len: PCardinal): Integer; cdecl;

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

procedure TestGetFingerprintShouldFailControlledWhenX509DigestIsUnavailable;
var
  LFixturePEM: string;
  LFixtureFingerprint: string;
  LOriginalX509Digest: TX509DigestFunc;
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
  LTryFingerprint: string;
begin
  WriteLn;
  WriteLn('=== Certificate utils fingerprint X509_digest symbol guard ===');

  if (not Assigned(BIO_new_mem_buf)) or
     (not Assigned(PEM_read_bio_X509)) or
     (not Assigned(BIO_free)) or
     (not Assigned(X509_digest)) or
     (not Assigned(EVP_sha256)) then
  begin
    MarkSkip('certificate utils fingerprint X509_digest symbol contract',
      'required baseline OpenSSL BIO/PEM/X509/EVP helpers are unavailable');
    Exit;
  end;

  WarmupFingerprintMaterial(LFixturePEM, LFixtureFingerprint);
  if LFixtureFingerprint = '' then
    raise Exception.Create('warmup fingerprint unexpectedly empty');

  LOriginalX509Digest := X509_digest;
  try
    X509_digest := nil;

    LRaised := False;
    LControlled := False;
    LDetail := '';
    try
      TCertificateUtils.GetFingerprint(LFixturePEM);
    except
      on E: Exception do
      begin
        LRaised := True;
        LControlled := E is ESSLCertError;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    LTryRaised := False;
    LTryDetail := '';
    LTryFingerprint := 'sentinel';
    try
      LTryResult := TCertificateUtils.TryGetFingerprint(LFixturePEM, LTryFingerprint);
    except
      on E: Exception do
      begin
        LTryRaised := True;
        LTryDetail := E.ClassName + ': ' + E.Message;
        LTryResult := True;
      end;
    end;

    AssertTrue('GetFingerprint when X509_digest is unavailable should raise',
      LRaised, 'expected GetFingerprint to fail');
    AssertTrue('GetFingerprint when X509_digest is unavailable should raise controlled ESSLCertError',
      LControlled, LDetail);
    AssertTrue('TryGetFingerprint when X509_digest is unavailable should not raise',
      not LTryRaised, LTryDetail);
    AssertTrue('TryGetFingerprint when X509_digest is unavailable should return False',
      not LTryResult,
      'expected TryGetFingerprint to return False');
    AssertTrue('TryGetFingerprint when X509_digest is unavailable should clear output',
      LTryFingerprint = '',
      'expected TryGetFingerprint output to be empty');
  finally
    X509_digest := LOriginalX509Digest;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils Fingerprint X509_digest Symbol Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils fingerprint X509_digest symbol contract',
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
      TestGetFingerprintShouldFailControlledWhenX509DigestIsUnavailable;

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
