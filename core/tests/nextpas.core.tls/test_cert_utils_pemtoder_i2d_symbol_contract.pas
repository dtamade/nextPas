program test_cert_utils_pemtoder_i2d_symbol_contract;

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

procedure WarmupPEMToDERMaterial(out APEM: string; out ADER: TBytes);
begin
  APEM := LoadFixturePEM;
  if APEM = '' then
    raise Exception.Create('certificate fixture is empty');

  ADER := TCertificateUtils.PEMToDER(APEM);
  if Length(ADER) = 0 then
    raise Exception.Create('failed to warm up PEMToDER');
end;

procedure TestPEMToDERShouldDegradeSafelyWhenI2DX509IsUnavailable;
var
  LFixturePEM: string;
  LFixtureDER: TBytes;
  LOriginalI2DX509: Ti2d_X509;
  LRaised: Boolean;
  LDetail: string;
  LResult: TBytes;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
  LTryDER: TBytes;
begin
  WriteLn;
  WriteLn('=== Certificate utils PEMToDER i2d symbol guard ===');

  if (not Assigned(BIO_new_mem_buf)) or
     (not Assigned(PEM_read_bio_X509)) or
     (not Assigned(BIO_free)) or
     (not Assigned(i2d_X509)) then
  begin
    MarkSkip('certificate utils PEMToDER i2d symbol contract',
      'required baseline OpenSSL BIO/PEM/X509 helpers are unavailable');
    Exit;
  end;

  WarmupPEMToDERMaterial(LFixturePEM, LFixtureDER);
  if Length(LFixtureDER) = 0 then
    raise Exception.Create('warmup DER unexpectedly empty');

  LOriginalI2DX509 := i2d_X509;
  try
    i2d_X509 := nil;

    LRaised := False;
    LDetail := '';
    SetLength(LResult, 1);
    LResult[0] := 42;
    try
      LResult := TCertificateUtils.PEMToDER(LFixturePEM);
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
      LTryResult := TCertificateUtils.TryPEMToDER(LFixturePEM, LTryDER);
    except
      on E: Exception do
      begin
        LTryRaised := True;
        LTryDetail := E.ClassName + ': ' + E.Message;
        LTryResult := True;
      end;
    end;

    AssertTrue('PEMToDER when i2d_X509 is unavailable should not raise',
      not LRaised, LDetail);
    AssertTrue('PEMToDER when i2d_X509 is unavailable should return empty bytes',
      Length(LResult) = 0,
      'expected PEMToDER to preserve its empty-bytes contract');
    AssertTrue('TryPEMToDER when i2d_X509 is unavailable should not raise',
      not LTryRaised, LTryDetail);
    AssertTrue('TryPEMToDER when i2d_X509 is unavailable should return False',
      not LTryResult,
      'expected TryPEMToDER to return False');
    AssertTrue('TryPEMToDER when i2d_X509 is unavailable should clear output',
      Length(LTryDER) = 0,
      'expected TryPEMToDER output to be empty');
  finally
    i2d_X509 := LOriginalI2DX509;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils PEMToDER i2d Symbol Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils PEMToDER i2d symbol contract',
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
      TestPEMToDERShouldDegradeSafelyWhenI2DX509IsUnavailable;

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
