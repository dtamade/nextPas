program test_cert_utils_dertopem_d2i_symbol_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem;

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

procedure TestDERToPEMShouldDegradeSafelyWhenD2IX509IsUnavailable;
var
  LFixtureDER: TBytes;
  LFixturePEM: string;
  LOriginalD2IX509: Td2i_X509;
  LRaised: Boolean;
  LDetail: string;
  LResult: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
  LTryPEM: string;
begin
  WriteLn;
  WriteLn('=== Certificate utils DERToPEM d2i symbol guard ===');

  if (not Assigned(d2i_X509)) or
     (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(PEM_write_bio_X509)) or
     (not Assigned(BIO_free)) then
  begin
    MarkSkip('certificate utils DERToPEM d2i symbol contract',
      'required baseline OpenSSL X509/BIO/PEM helpers are unavailable');
    Exit;
  end;

  WarmupDERToPEMMaterial(LFixtureDER, LFixturePEM);
  if LFixturePEM = '' then
    raise Exception.Create('warmup PEM unexpectedly empty');

  LOriginalD2IX509 := d2i_X509;
  try
    d2i_X509 := nil;

    LRaised := False;
    LDetail := '';
    LResult := 'sentinel';
    try
      LResult := TCertificateUtils.DERToPEM(LFixtureDER);
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
      LTryResult := TCertificateUtils.TryDERToPEM(LFixtureDER, LTryPEM);
    except
      on E: Exception do
      begin
        LTryRaised := True;
        LTryDetail := E.ClassName + ': ' + E.Message;
        LTryResult := True;
      end;
    end;

    AssertTrue('DERToPEM when d2i_X509 is unavailable should not raise',
      not LRaised, LDetail);
    AssertTrue('DERToPEM when d2i_X509 is unavailable should return empty string',
      LResult = '',
      'expected DERToPEM to preserve its empty-string contract');
    AssertTrue('TryDERToPEM when d2i_X509 is unavailable should not raise',
      not LTryRaised, LTryDetail);
    AssertTrue('TryDERToPEM when d2i_X509 is unavailable should return False',
      not LTryResult,
      'expected TryDERToPEM to return False');
    AssertTrue('TryDERToPEM when d2i_X509 is unavailable should clear output',
      LTryPEM = '',
      'expected TryDERToPEM output to be empty');
  finally
    d2i_X509 := LOriginalD2IX509;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils DERToPEM d2i Symbol Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils DERToPEM d2i symbol contract',
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
      TestDERToPEMShouldDegradeSafelyWhenD2IX509IsUnavailable;

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
