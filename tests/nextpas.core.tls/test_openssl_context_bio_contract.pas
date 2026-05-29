program test_openssl_context_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem;

const
  CERT_FIXTURE_PATH = 'tests/certificate/test_certs/signer_cert.pem';
  KEY_FIXTURE_PATH = 'tests/certificate/test_certs/signer_key.pem';
  PASSWORD_SENTINEL = 'context-bio-contract';

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

function CreateServerContext: ISSLContext;
begin
  Result := GLib.CreateContext(sslCtxServer);
  if Result = nil then
    raise Exception.Create('failed to create OpenSSL server context');
end;

procedure AssertLoadCertificateStreamControlledFailure(const AName, ACertificatePEM: string);
var
  LCtx: ISSLContext;
  LStream: TStringStream;
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
begin
  LCtx := CreateServerContext;
  LStream := TStringStream.Create(ACertificatePEM);
  try
    LRaised := False;
    LControlled := False;
    LDetail := '';
    try
      LCtx.LoadCertificate(LStream);
    except
      on E: Exception do
      begin
        LRaised := True;
        LControlled := E is ESSLException;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should raise', LRaised,
      'expected LoadCertificate(AStream) to fail');
    AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
  finally
    LStream.Free;
  end;
end;

procedure AssertLoadCertificatePEMControlledFailure(const AName, ACertificatePEM: string);
var
  LCtx: ISSLContext;
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
begin
  LCtx := CreateServerContext;
  LRaised := False;
  LControlled := False;
  LDetail := '';
  try
    LCtx.LoadCertificatePEM(ACertificatePEM);
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLException;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected LoadCertificatePEM to fail');
  AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
end;

procedure AssertLoadPrivateKeyFileControlledFailure(
  const AName, AFileName, APassword: string);
var
  LCtx: ISSLContext;
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
begin
  LCtx := CreateServerContext;
  LRaised := False;
  LControlled := False;
  LDetail := '';
  try
    LCtx.LoadPrivateKey(AFileName, APassword);
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLException;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected LoadPrivateKey(file, password) to fail');
  AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
end;

procedure AssertLoadPrivateKeyStreamControlledFailure(
  const AName, APrivateKeyPEM, APassword: string);
var
  LCtx: ISSLContext;
  LStream: TStringStream;
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
begin
  LCtx := CreateServerContext;
  LStream := TStringStream.Create(APrivateKeyPEM);
  try
    LRaised := False;
    LControlled := False;
    LDetail := '';
    try
      LCtx.LoadPrivateKey(LStream, APassword);
    except
      on E: Exception do
      begin
        LRaised := True;
        LControlled := E is ESSLException;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should raise', LRaised,
      'expected LoadPrivateKey(AStream, password) to fail');
    AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
  finally
    LStream.Free;
  end;
end;

procedure AssertLoadPrivateKeyPEMControlledFailure(
  const AName, APrivateKeyPEM, APassword: string);
var
  LCtx: ISSLContext;
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
begin
  LCtx := CreateServerContext;
  LRaised := False;
  LControlled := False;
  LDetail := '';
  try
    LCtx.LoadPrivateKeyPEM(APrivateKeyPEM, APassword);
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLException;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected LoadPrivateKeyPEM to fail');
  AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
end;

procedure TestContextHelpersShouldRaiseControlledExceptionsWhenBIOHelpersAreUnavailable;
var
  LCertPEM: string;
  LKeyPEM: string;
  LOriginalBIONewFile: TBIO_new_file;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIOFree: TBIO_free;
begin
  WriteLn;
  WriteLn('=== OpenSSL context BIO guard ===');

  LCertPEM := LoadFixtureText(CERT_FIXTURE_PATH);
  LKeyPEM := LoadFixtureText(KEY_FIXTURE_PATH);
  if (LCertPEM = '') or (LKeyPEM = '') then
    raise Exception.Create('certificate/private-key fixtures are empty');

  if (not Assigned(BIO_new_file)) or
     (not Assigned(BIO_new_mem_buf)) or
     (not Assigned(BIO_free)) or
     (not Assigned(PEM_read_bio_X509)) or
     (not Assigned(PEM_read_bio_PrivateKey)) then
  begin
    MarkSkip('openssl context bio contract',
      'required baseline OpenSSL BIO/PEM helpers are unavailable');
    Exit;
  end;

  LOriginalBIONewFile := BIO_new_file;
  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalBIOFree := BIO_free;

  BIO_new_mem_buf := nil;
  try
    AssertLoadCertificateStreamControlledFailure(
      'LoadCertificate(AStream) when BIO_new_mem_buf is unavailable', LCertPEM);
    AssertLoadCertificatePEMControlledFailure(
      'LoadCertificatePEM when BIO_new_mem_buf is unavailable', LCertPEM);
    AssertLoadPrivateKeyStreamControlledFailure(
      'LoadPrivateKey(AStream) when BIO_new_mem_buf is unavailable', LKeyPEM, PASSWORD_SENTINEL);
    AssertLoadPrivateKeyPEMControlledFailure(
      'LoadPrivateKeyPEM when BIO_new_mem_buf is unavailable', LKeyPEM, PASSWORD_SENTINEL);
  finally
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
  end;

  BIO_new_file := nil;
  try
    AssertLoadPrivateKeyFileControlledFailure(
      'LoadPrivateKey(file) when BIO_new_file is unavailable',
      KEY_FIXTURE_PATH,
      PASSWORD_SENTINEL
    );
  finally
    BIO_new_file := LOriginalBIONewFile;
  end;

  BIO_free := nil;
  try
    AssertLoadCertificateStreamControlledFailure(
      'LoadCertificate(AStream) when BIO_free is unavailable', LCertPEM);
    AssertLoadCertificatePEMControlledFailure(
      'LoadCertificatePEM when BIO_free is unavailable', LCertPEM);
    AssertLoadPrivateKeyFileControlledFailure(
      'LoadPrivateKey(file) when BIO_free is unavailable',
      KEY_FIXTURE_PATH,
      PASSWORD_SENTINEL
    );
    AssertLoadPrivateKeyStreamControlledFailure(
      'LoadPrivateKey(AStream) when BIO_free is unavailable', LKeyPEM, PASSWORD_SENTINEL);
    AssertLoadPrivateKeyPEMControlledFailure(
      'LoadPrivateKeyPEM when BIO_free is unavailable', LKeyPEM, PASSWORD_SENTINEL);
  finally
    BIO_free := LOriginalBIOFree;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('OpenSSL Context BIO Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('openssl context bio contract', 'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      LoadOpenSSLX509();
      if not LoadOpenSSLPEM(GetCryptoLibHandle) then
        raise Exception.Create('failed to load PEM support');
    end;

    if SkippedTests = 0 then
      TestContextHelpersShouldRaiseControlledExceptionsWhenBIOHelpersAreUnavailable;

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
