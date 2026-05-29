program test_cert_builder_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.cert.builder.impl;

const
  CERT_FIXTURE_PATH = 'tests/certificate/test_certs/signer_cert.pem';
  KEY_FIXTURE_PATH = 'tests/certificate/test_certs/signer_key.pem';

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

function LoadFixtureText(const APath: string): string;
var
  LText: TStringList;
begin
  LText := TStringList.Create;
  try
    LText.LoadFromFile(APath);
    Result := LText.Text;
  finally
    LText.Free;
  end;
end;

function CreateCertificateHandleFromPEM(const APEM: string): PX509;
var
  LBio: PBIO;
begin
  Result := nil;
  LBio := BIO_new_mem_buf(PAnsiChar(AnsiString(APEM)), Length(APEM));
  if LBio = nil then
    raise Exception.Create('failed to create certificate fixture BIO');

  try
    Result := PEM_read_bio_X509(LBio, nil, nil, nil);
    if Result = nil then
      raise Exception.Create('failed to parse certificate fixture handle');
  finally
    BIO_free(LBio);
  end;
end;

function CreatePrivateKeyHandleFromPEM(const APEM: string): PEVP_PKEY;
var
  LBio: PBIO;
begin
  Result := nil;
  LBio := BIO_new_mem_buf(PAnsiChar(AnsiString(APEM)), Length(APEM));
  if LBio = nil then
    raise Exception.Create('failed to create private-key fixture BIO');

  try
    Result := PEM_read_bio_PrivateKey(LBio, nil, nil, nil);
    if Result = nil then
      raise Exception.Create('failed to parse private-key fixture handle');
  finally
    BIO_free(LBio);
  end;
end;

procedure AssertPreparedCertificateGetHandleControlledFailure(const AName: string; ACert: TCertificateImpl);
var
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
begin
  LRaised := False;
  LControlled := False;
  LDetail := '';
  try
    ACert.GetX509Handle;
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLException;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised, 'expected GetX509Handle to fail');
  AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
end;

procedure AssertPreparedPrivateKeyGetHandleControlledFailure(const AName: string; AKey: TPrivateKeyImpl);
var
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
begin
  LRaised := False;
  LControlled := False;
  LDetail := '';
  try
    AKey.GetEVP_PKEYHandle;
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLException;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised, 'expected GetEVP_PKEYHandle to fail');
  AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
end;

procedure AssertCertificateCreateFromHandleControlledFailure(const AName: string; AHandle: PX509);
var
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
  LCert: TCertificateImpl;
begin
  LRaised := False;
  LControlled := False;
  LDetail := '';
  LCert := nil;
  try
    try
      LCert := TCertificateImpl.CreateFromHandle(AHandle, False);
    except
      on E: Exception do
      begin
        LRaised := True;
        LControlled := E is ESSLException;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should raise', LRaised, 'expected CreateFromHandle to fail');
    AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
  finally
    LCert.Free;
  end;
end;

procedure AssertPrivateKeyCreateFromHandleControlledFailure(const AName: string; AHandle: PEVP_PKEY);
var
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
  LKey: TPrivateKeyImpl;
begin
  LRaised := False;
  LControlled := False;
  LDetail := '';
  LKey := nil;
  try
    try
      LKey := TPrivateKeyImpl.CreateFromHandle(AHandle, False);
    except
      on E: Exception do
      begin
        LRaised := True;
        LControlled := E is ESSLException;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should raise', LRaised, 'expected CreateFromHandle to fail');
    AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
  finally
    LKey.Free;
  end;
end;

procedure TestCertBuilderHelpersShouldFailGracefullyWhenBIOHelpersAreUnavailable;
var
  LCertPEM: string;
  LKeyPEM: string;
  LCertObj: TCertificateImpl;
  LKeyObj: TPrivateKeyImpl;
  LCertHandle: PX509;
  LKeyHandle: PEVP_PKEY;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalBIOFree: TBIO_free;
begin
  WriteLn;
  WriteLn('=== Cert builder BIO guard ===');

  LCertPEM := LoadFixtureText(CERT_FIXTURE_PATH);
  LKeyPEM := LoadFixtureText(KEY_FIXTURE_PATH);
  if (LCertPEM = '') or (LKeyPEM = '') then
    raise Exception.Create('certificate/private-key fixtures are empty');

  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalBIONew := BIO_new;
  LOriginalBIOSMem := BIO_s_mem;
  LOriginalBIOFree := BIO_free;

  LCertObj := TCertificateImpl.Create(LCertPEM);
  LKeyObj := TPrivateKeyImpl.Create(LKeyPEM);
  try
    BIO_new_mem_buf := nil;
    try
      AssertPreparedCertificateGetHandleControlledFailure(
        'TCertificateImpl.GetX509Handle when BIO_new_mem_buf is unavailable', LCertObj);
      AssertPreparedPrivateKeyGetHandleControlledFailure(
        'TPrivateKeyImpl.GetEVP_PKEYHandle when BIO_new_mem_buf is unavailable', LKeyObj);
    finally
      BIO_new_mem_buf := LOriginalBIONewMemBuf;
    end;
  finally
    LCertObj.Free;
    LKeyObj.Free;
  end;

  LCertHandle := CreateCertificateHandleFromPEM(LCertPEM);
  LKeyHandle := CreatePrivateKeyHandleFromPEM(LKeyPEM);
  BIO_new := nil;
  try
    AssertCertificateCreateFromHandleControlledFailure(
      'TCertificateImpl.CreateFromHandle when BIO_new is unavailable', LCertHandle);
    AssertPrivateKeyCreateFromHandleControlledFailure(
      'TPrivateKeyImpl.CreateFromHandle when BIO_new is unavailable', LKeyHandle);
  finally
    BIO_new := LOriginalBIONew;
    X509_free(LCertHandle);
    if Assigned(EVP_PKEY_free) then
      EVP_PKEY_free(LKeyHandle);
  end;

  LCertHandle := CreateCertificateHandleFromPEM(LCertPEM);
  LKeyHandle := CreatePrivateKeyHandleFromPEM(LKeyPEM);
  BIO_s_mem := nil;
  try
    AssertCertificateCreateFromHandleControlledFailure(
      'TCertificateImpl.CreateFromHandle when BIO_s_mem is unavailable', LCertHandle);
    AssertPrivateKeyCreateFromHandleControlledFailure(
      'TPrivateKeyImpl.CreateFromHandle when BIO_s_mem is unavailable', LKeyHandle);
  finally
    BIO_s_mem := LOriginalBIOSMem;
    X509_free(LCertHandle);
    if Assigned(EVP_PKEY_free) then
      EVP_PKEY_free(LKeyHandle);
  end;

  LCertHandle := CreateCertificateHandleFromPEM(LCertPEM);
  LKeyHandle := CreatePrivateKeyHandleFromPEM(LKeyPEM);
  LCertObj := TCertificateImpl.Create(LCertPEM);
  LKeyObj := TPrivateKeyImpl.Create(LKeyPEM);
  try
    BIO_free := nil;
    try
      AssertPreparedCertificateGetHandleControlledFailure(
        'TCertificateImpl.GetX509Handle when BIO_free is unavailable', LCertObj);
      AssertPreparedPrivateKeyGetHandleControlledFailure(
        'TPrivateKeyImpl.GetEVP_PKEYHandle when BIO_free is unavailable', LKeyObj);
      AssertCertificateCreateFromHandleControlledFailure(
        'TCertificateImpl.CreateFromHandle when BIO_free is unavailable', LCertHandle);
      AssertPrivateKeyCreateFromHandleControlledFailure(
        'TPrivateKeyImpl.CreateFromHandle when BIO_free is unavailable', LKeyHandle);
    finally
      BIO_free := LOriginalBIOFree;
    end;
  finally
    LCertObj.Free;
    LKeyObj.Free;
    X509_free(LCertHandle);
    if Assigned(EVP_PKEY_free) then
      EVP_PKEY_free(LKeyHandle);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Cert Builder BIO Contract Test');
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
        MarkSkip('cert builder bio contract',
          'failed to load OpenSSL cert-builder dependencies: ' + E.Message);
      end;
    end;

    if SkippedTests = 0 then
      TestCertBuilderHelpersShouldFailGracefullyWhenBIOHelpersAreUnavailable;

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
