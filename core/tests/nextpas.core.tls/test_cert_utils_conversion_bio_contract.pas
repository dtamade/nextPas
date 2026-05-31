program test_cert_utils_conversion_bio_contract;

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

procedure WarmupCertificateUtilsMaterials(
  out APEM: string;
  out ADER: TBytes;
  out AFingerprint: string
);
var
  LRoundTripPEM: string;
begin
  APEM := LoadFixturePEM;
  if APEM = '' then
    raise Exception.Create('certificate fixture is empty');

  ADER := TCertificateUtils.PEMToDER(APEM);
  if Length(ADER) = 0 then
    raise Exception.Create('failed to warm up PEMToDER');

  LRoundTripPEM := TCertificateUtils.DERToPEM(ADER);
  if LRoundTripPEM = '' then
    raise Exception.Create('failed to warm up DERToPEM');

  AFingerprint := TCertificateUtils.GetFingerprint(APEM);
  if AFingerprint = '' then
    raise Exception.Create('failed to warm up GetFingerprint');
end;

procedure AssertPEMToDERSafeDegrade(const AName, APEM: string);
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
  SetLength(LResult, 1);
  LResult[0] := 42;
  try
    LResult := TCertificateUtils.PEMToDER(APEM);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  LTryRaised := False;
  LTryDetail := '';
  SetLength(LTryDER, 1);
  LTryDER[0] := 42;
  try
    LTryResult := TCertificateUtils.TryPEMToDER(APEM, LTryDER);
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
      LTryResult := True;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should return empty bytes', Length(LResult) = 0,
    'expected PEMToDER to return empty bytes');
  AssertTrue(AName + ' Try wrapper should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' Try wrapper should return False', not LTryResult,
    'expected TryPEMToDER to return False');
  AssertTrue(AName + ' Try wrapper should clear output', Length(LTryDER) = 0,
    'expected TryPEMToDER output to be empty');
end;

procedure AssertDERToPEMSafeDegrade(const AName: string; const ADER: TBytes);
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
  try
    LResult := TCertificateUtils.DERToPEM(ADER);
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
  try
    LTryResult := TCertificateUtils.TryDERToPEM(ADER, LTryPEM);
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
    'expected DERToPEM to return empty string');
  AssertTrue(AName + ' Try wrapper should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' Try wrapper should return False', not LTryResult,
    'expected TryDERToPEM to return False');
  AssertTrue(AName + ' Try wrapper should clear output', LTryPEM = '',
    'expected TryDERToPEM output to be empty');
end;

procedure AssertFingerprintControlledFailure(const AName, APEM: string);
var
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
  LTryFingerprint: string;
begin
  LRaised := False;
  LControlled := False;
  LDetail := '';
  try
    TCertificateUtils.GetFingerprint(APEM);
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
    LTryResult := TCertificateUtils.TryGetFingerprint(APEM, LTryFingerprint);
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
      LTryResult := True;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected GetFingerprint to fail');
  AssertTrue(AName + ' should raise controlled ESSLCertError', LControlled, LDetail);
  AssertTrue(AName + ' Try wrapper should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' Try wrapper should return False', not LTryResult,
    'expected TryGetFingerprint to return False');
  AssertTrue(AName + ' Try wrapper should clear output', LTryFingerprint = '',
    'expected TryGetFingerprint output to be empty');
end;

procedure TestCertificateUtilsHelpersShouldFailGracefullyWhenBIOHelpersAreUnavailable;
var
  LFixturePEM: string;
  LFixtureDER: TBytes;
  LFixtureFingerprint: string;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalBIOFree: TBIO_free;
begin
  WriteLn;
  WriteLn('=== Certificate utils conversion BIO guard ===');

  if (not Assigned(BIO_new_mem_buf)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(BIO_free)) or
     (not Assigned(PEM_read_bio_X509)) or
     (not Assigned(PEM_write_bio_X509)) then
  begin
    MarkSkip('certificate utils conversion bio contract',
      'required baseline OpenSSL BIO/PEM/X509 helpers are unavailable');
    Exit;
  end;

  WarmupCertificateUtilsMaterials(LFixturePEM, LFixtureDER, LFixtureFingerprint);
  if LFixtureFingerprint = '' then
    raise Exception.Create('fingerprint warmup unexpectedly returned empty');

  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalBIONew := BIO_new;
  LOriginalBIOSMem := BIO_s_mem;
  LOriginalBIOFree := BIO_free;

  BIO_new_mem_buf := nil;
  try
    AssertPEMToDERSafeDegrade('PEMToDER when BIO_new_mem_buf is unavailable', LFixturePEM);
    AssertFingerprintControlledFailure('GetFingerprint when BIO_new_mem_buf is unavailable', LFixturePEM);
  finally
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
  end;

  BIO_new := nil;
  try
    AssertDERToPEMSafeDegrade('DERToPEM when BIO_new is unavailable', LFixtureDER);
  finally
    BIO_new := LOriginalBIONew;
  end;

  BIO_s_mem := nil;
  try
    AssertDERToPEMSafeDegrade('DERToPEM when BIO_s_mem is unavailable', LFixtureDER);
  finally
    BIO_s_mem := LOriginalBIOSMem;
  end;

  BIO_free := nil;
  try
    AssertPEMToDERSafeDegrade('PEMToDER when BIO_free is unavailable', LFixturePEM);
    AssertDERToPEMSafeDegrade('DERToPEM when BIO_free is unavailable', LFixtureDER);
    AssertFingerprintControlledFailure('GetFingerprint when BIO_free is unavailable', LFixturePEM);
  finally
    BIO_free := LOriginalBIOFree;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils Conversion BIO Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils conversion bio contract',
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
      TestCertificateUtilsHelpersShouldFailGracefullyWhenBIOHelpersAreUnavailable;

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
