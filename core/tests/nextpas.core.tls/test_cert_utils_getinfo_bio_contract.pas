program test_cert_utils_getinfo_bio_contract;

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

procedure WarmupGetInfo(const APEM: string);
var
  LInfo: TCertInfo;
begin
  LInfo := TCertificateUtils.GetInfo(APEM);
  try
    if LInfo.Subject = '' then
      raise Exception.Create('GetInfo warmup returned empty subject');
    if not Assigned(LInfo.SubjectAltNames) then
      raise Exception.Create('GetInfo warmup returned nil SubjectAltNames');
  finally
    if Assigned(LInfo.SubjectAltNames) then
      LInfo.SubjectAltNames.Free;
  end;
end;

procedure AssertEmptyInfo(const AName: string; const AInfo: TCertInfo);
begin
  AssertTrue(AName + ' should return empty subject', AInfo.Subject = '',
    'Subject=' + AInfo.Subject);
  AssertTrue(AName + ' should return empty issuer', AInfo.Issuer = '',
    'Issuer=' + AInfo.Issuer);
  AssertTrue(AName + ' should return empty serial number', AInfo.SerialNumber = '',
    'SerialNumber=' + AInfo.SerialNumber);
  AssertTrue(AName + ' should return empty key usage', AInfo.KeyUsage = '',
    'KeyUsage=' + AInfo.KeyUsage);
  AssertTrue(AName + ' should return zero version', AInfo.Version = 0,
    'Version=' + IntToStr(AInfo.Version));
  AssertTrue(AName + ' should allocate SubjectAltNames', Assigned(AInfo.SubjectAltNames),
    'SubjectAltNames=nil');
  if Assigned(AInfo.SubjectAltNames) then
    AssertTrue(AName + ' should keep SubjectAltNames empty', AInfo.SubjectAltNames.Count = 0,
      'Count=' + IntToStr(AInfo.SubjectAltNames.Count));
end;

procedure AssertGetInfoSafeDegrade(const AName, APEM: string);
var
  LRaised: Boolean;
  LDetail: string;
  LInfo: TCertInfo;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryInfo: TCertInfo;
  LTryResult: Boolean;
begin
  LRaised := False;
  LDetail := '';
  try
    LInfo := TCertificateUtils.GetInfo(APEM);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  if not LRaised then
  begin
    try
      AssertEmptyInfo(AName, LInfo);
    finally
      if Assigned(LInfo.SubjectAltNames) then
        LInfo.SubjectAltNames.Free;
    end;
  end;

  LTryRaised := False;
  LTryDetail := '';
  LTryResult := False;
  FillChar(LTryInfo, SizeOf(LTryInfo), 0);
  try
    LTryResult := TCertificateUtils.TryGetInfo(APEM, LTryInfo);
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' Try wrapper should not raise', not LTryRaised, LTryDetail);
  if not LTryRaised then
  begin
    try
      AssertEmptyInfo(AName + ' Try wrapper', LTryInfo);
      AssertTrue(AName + ' Try wrapper return is acceptable',
        (not LTryResult) or (LTryInfo.Subject = ''),
        'unexpected TryGetInfo result state');
    finally
      if Assigned(LTryInfo.SubjectAltNames) then
        LTryInfo.SubjectAltNames.Free;
    end;
  end;
end;

procedure TestGetInfoShouldFailGracefullyWhenBIOHelpersAreUnavailable;
var
  LFixturePEM: string;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIOFree: TBIO_free;
begin
  WriteLn;
  WriteLn('=== Certificate utils GetInfo BIO guard ===');

  if (not Assigned(BIO_new_mem_buf)) or
     (not Assigned(BIO_free)) or
     (not Assigned(PEM_read_bio_X509)) then
  begin
    MarkSkip('certificate utils getinfo bio contract',
      'required baseline OpenSSL BIO/PEM/X509 helpers are unavailable');
    Exit;
  end;

  LFixturePEM := LoadFixturePEM;
  if LFixturePEM = '' then
    raise Exception.Create('certificate fixture is empty');

  WarmupGetInfo(LFixturePEM);

  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  BIO_new_mem_buf := nil;
  try
    AssertGetInfoSafeDegrade('GetInfo when BIO_new_mem_buf is unavailable', LFixturePEM);
  finally
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
  end;

  LOriginalBIOFree := BIO_free;
  BIO_free := nil;
  try
    AssertGetInfoSafeDegrade('GetInfo when BIO_free is unavailable', LFixturePEM);
  finally
    BIO_free := LOriginalBIOFree;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils GetInfo BIO Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils getinfo bio contract',
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
      TestGetInfoShouldFailGracefullyWhenBIOHelpersAreUnavailable;

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
