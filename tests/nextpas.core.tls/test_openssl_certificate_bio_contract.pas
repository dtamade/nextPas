program test_openssl_certificate_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.certificate;

const
  CERT_FIXTURE_PATH = 'tests/certificate/test_certs/signer_cert.pem';
  TEMP_OUTPUT_PATH = 'tmp/openssl_certificate_bio_contract/output-cert.pem';

var
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

function AnsiStringToBytes(const AValue: AnsiString): TBytes;
begin
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
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

function CreateLoadedCertificate(const APEM: string): TOpenSSLCertificate;
begin
  Result := TOpenSSLCertificate.Create(nil, False);
  if not Result.LoadFromPEM(APEM) then
  begin
    Result.Free;
    raise Exception.Create('failed to load certificate fixture into TOpenSSLCertificate');
  end;
end;

procedure WarmupCertificateHelpers(
  out APEM: string;
  out APEMBytes: TBytes;
  out ADERBytes: TBytes
);
var
  LCert: TOpenSSLCertificate;
begin
  APEM := LoadFixturePEM;
  if APEM = '' then
    raise Exception.Create('certificate fixture is empty');

  APEMBytes := AnsiStringToBytes(AnsiString(APEM));
  if Length(APEMBytes) = 0 then
    raise Exception.Create('certificate fixture bytes are empty');

  LCert := CreateLoadedCertificate(APEM);
  try
    if LCert.SaveToPEM() = '' then
      raise Exception.Create('failed to warm up PEM save path');

    ADERBytes := LCert.SaveToDER();
    if Length(ADERBytes) = 0 then
      raise Exception.Create('failed to warm up DER save path');
  finally
    LCert.Free;
  end;
end;

procedure EnsureTempOutputDir;
begin
  ForceDirectories(ExtractFileDir(TEMP_OUTPUT_PATH));
end;

procedure AssertLoadFromFileSafeDegrade(const AName: string);
var
  LCert: TOpenSSLCertificate;
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
begin
  LCert := TOpenSSLCertificate.Create(nil, False);
  try
    LRaised := False;
    LDetail := '';
    LResult := True;
    try
      LResult := LCert.LoadFromFile(CERT_FIXTURE_PATH);
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should return False', not LResult,
      'expected LoadFromFile to return False');
  finally
    LCert.Free;
  end;
end;

procedure AssertLoadFromPEMSafeDegrade(const AName, APEM: string);
var
  LCert: TOpenSSLCertificate;
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
begin
  LCert := TOpenSSLCertificate.Create(nil, False);
  try
    LRaised := False;
    LDetail := '';
    LResult := True;
    try
      LResult := LCert.LoadFromPEM(APEM);
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should return False', not LResult,
      'expected LoadFromPEM to return False');
  finally
    LCert.Free;
  end;
end;

procedure AssertLoadFromMemorySafeDegrade(const AName: string; const AData: TBytes);
var
  LCert: TOpenSSLCertificate;
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
begin
  LCert := TOpenSSLCertificate.Create(nil, False);
  try
    LRaised := False;
    LDetail := '';
    LResult := True;
    try
      LResult := LCert.LoadFromMemory(@AData[0], Length(AData));
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
    AssertTrue(AName + ' should return False', not LResult,
      'expected LoadFromMemory to return False');
  finally
    LCert.Free;
  end;
end;

procedure AssertPreparedSaveToFileSafeDegrade(const AName: string; ACert: TOpenSSLCertificate);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
begin
  EnsureTempOutputDir;
  DeleteFile(TEMP_OUTPUT_PATH);

  LRaised := False;
  LDetail := '';
  LResult := True;
  try
    LResult := ACert.SaveToFile(TEMP_OUTPUT_PATH);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should return False', not LResult,
    'expected SaveToFile to return False');
  DeleteFile(TEMP_OUTPUT_PATH);
end;

procedure AssertSaveToFileSafeDegrade(const AName, APEM: string);
var
  LCert: TOpenSSLCertificate;
begin
  LCert := CreateLoadedCertificate(APEM);
  try
    AssertPreparedSaveToFileSafeDegrade(AName, LCert);
  finally
    LCert.Free;
  end;
end;

procedure AssertPreparedSaveToPEMSafeDegrade(const AName: string; ACert: TOpenSSLCertificate);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: string;
begin
  LRaised := False;
  LDetail := '';
  LResult := 'sentinel';
  try
    LResult := ACert.SaveToPEM();
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should return empty string', LResult = '',
    'expected SaveToPEM to return empty string');
end;

procedure AssertSaveToPEMSafeDegrade(const AName, APEM: string);
var
  LCert: TOpenSSLCertificate;
begin
  LCert := CreateLoadedCertificate(APEM);
  try
    AssertPreparedSaveToPEMSafeDegrade(AName, LCert);
  finally
    LCert.Free;
  end;
end;

procedure AssertPreparedSaveToDERSafeDegrade(const AName: string; ACert: TOpenSSLCertificate);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: TBytes;
begin
  LRaised := False;
  LDetail := '';
  SetLength(LResult, 1);
  LResult[0] := 42;
  try
    LResult := ACert.SaveToDER();
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should return empty bytes', Length(LResult) = 0,
    'expected SaveToDER to return empty bytes');
end;

procedure AssertSaveToDERSafeDegrade(const AName, APEM: string);
var
  LCert: TOpenSSLCertificate;
begin
  LCert := CreateLoadedCertificate(APEM);
  try
    AssertPreparedSaveToDERSafeDegrade(AName, LCert);
  finally
    LCert.Free;
  end;
end;

procedure TestCertificateHelpersShouldFailGracefullyWhenBIOHelpersAreUnavailable;
var
  LFixturePEM: string;
  LFixturePEMBytes: TBytes;
  LFixtureDERBytes: TBytes;
  LPreparedSaveFileCert: TOpenSSLCertificate;
  LPreparedSavePEMCert: TOpenSSLCertificate;
  LPreparedSaveDERCert: TOpenSSLCertificate;
  LOriginalBIONewFile: TBIO_new_file;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalBIOFree: TBIO_free;
begin
  WriteLn;
  WriteLn('=== OpenSSL certificate BIO guard ===');

  WarmupCertificateHelpers(LFixturePEM, LFixturePEMBytes, LFixtureDERBytes);
  LPreparedSaveFileCert := nil;
  LPreparedSavePEMCert := nil;
  LPreparedSaveDERCert := nil;

  LOriginalBIONewFile := BIO_new_file;
  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalBIONew := BIO_new;
  LOriginalBIOSMem := BIO_s_mem;
  LOriginalBIOFree := BIO_free;

  BIO_new_file := nil;
  try
    AssertLoadFromFileSafeDegrade('LoadFromFile when BIO_new_file is unavailable');
    AssertSaveToFileSafeDegrade('SaveToFile when BIO_new_file is unavailable', LFixturePEM);
  finally
    BIO_new_file := LOriginalBIONewFile;
  end;

  BIO_new_mem_buf := nil;
  try
    AssertLoadFromPEMSafeDegrade('LoadFromPEM when BIO_new_mem_buf is unavailable', LFixturePEM);
    AssertLoadFromMemorySafeDegrade('LoadFromMemory when BIO_new_mem_buf is unavailable', LFixturePEMBytes);
  finally
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
  end;

  BIO_new := nil;
  try
    AssertSaveToPEMSafeDegrade('SaveToPEM when BIO_new is unavailable', LFixturePEM);
    AssertSaveToDERSafeDegrade('SaveToDER when BIO_new is unavailable', LFixturePEM);
  finally
    BIO_new := LOriginalBIONew;
  end;

  BIO_s_mem := nil;
  try
    AssertSaveToPEMSafeDegrade('SaveToPEM when BIO_s_mem is unavailable', LFixturePEM);
    AssertSaveToDERSafeDegrade('SaveToDER when BIO_s_mem is unavailable', LFixturePEM);
  finally
    BIO_s_mem := LOriginalBIOSMem;
  end;

  LPreparedSaveFileCert := CreateLoadedCertificate(LFixturePEM);
  LPreparedSavePEMCert := CreateLoadedCertificate(LFixturePEM);
  LPreparedSaveDERCert := CreateLoadedCertificate(LFixturePEM);
  BIO_free := nil;
  try
    AssertLoadFromFileSafeDegrade('LoadFromFile when BIO_free is unavailable');
    AssertLoadFromPEMSafeDegrade('LoadFromPEM when BIO_free is unavailable', LFixturePEM);
    AssertLoadFromMemorySafeDegrade('LoadFromMemory when BIO_free is unavailable', LFixturePEMBytes);
    AssertPreparedSaveToFileSafeDegrade('SaveToFile when BIO_free is unavailable', LPreparedSaveFileCert);
    AssertPreparedSaveToPEMSafeDegrade('SaveToPEM when BIO_free is unavailable', LPreparedSavePEMCert);
    AssertPreparedSaveToDERSafeDegrade('SaveToDER when BIO_free is unavailable', LPreparedSaveDERCert);
  finally
    LPreparedSaveFileCert.Free;
    LPreparedSavePEMCert.Free;
    LPreparedSaveDERCert.Free;
    BIO_free := LOriginalBIOFree;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Certificate BIO Contract Test');
  WriteLn('========================================');

  try
    try
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      LoadOpenSSLX509();
      if not LoadOpenSSLPEM(GetCryptoLibHandle) then
        raise Exception.Create('failed to load PEM support');
    except
      on E: Exception do
      begin
        MarkSkip('openssl certificate bio contract',
          'failed to load OpenSSL certificate dependencies: ' + E.Message);
      end;
    end;

    if SkippedTests = 0 then
      TestCertificateHelpersShouldFailGracefullyWhenBIOHelpersAreUnavailable;

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
