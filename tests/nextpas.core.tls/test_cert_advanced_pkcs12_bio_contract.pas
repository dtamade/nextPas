program test_cert_advanced_pkcs12_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.cert,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.cert.advanced,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.pkcs12;

const
  PKCS12_PASSWORD = 'test123';

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

procedure WarmupPKCS12Materials(
  out AKeyPair: IKeyPairWithCertificate;
  out AOptions: TPKCS12Options;
  out AP12Data: TBytes
);
begin
  AKeyPair := TCertificate.CreateSelfSigned('pkcs12-bio-guard.local');
  if AKeyPair = nil then
    raise Exception.Create('failed to create self-signed keypair fixture');

  AOptions := DefaultPKCS12Options;
  AOptions.FriendlyName := 'PKCS12 BIO Guard';
  AOptions.Password := PKCS12_PASSWORD;
  AOptions.Iterations := 2048;

  AP12Data := TPKCS12Manager.CreatePKCS12(
    AKeyPair.Certificate,
    AKeyPair.PrivateKey,
    AOptions
  );
  if Length(AP12Data) = 0 then
    raise Exception.Create('failed to warm up PKCS#12 fixture bytes');
end;

procedure AssertCreatePKCS12ControlledFailure(
  const AName: string;
  const AKeyPair: IKeyPairWithCertificate;
  const AOptions: TPKCS12Options
);
var
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
  LP12Data: TBytes;
begin
  LRaised := False;
  LControlled := False;
  LDetail := '';
  SetLength(LP12Data, 1);
  LP12Data[0] := 42;
  try
    LP12Data := TPKCS12Manager.CreatePKCS12(
      AKeyPair.Certificate,
      AKeyPair.PrivateKey,
      AOptions
    );
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLException;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected CreatePKCS12 to fail');
  AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
end;

procedure AssertLoadPKCS12SafeDegrade(
  const AName: string;
  const AP12Data: TBytes;
  const APassword: string
);
var
  LRaised: Boolean;
  LDetail: string;
  LResult: Boolean;
  LCert: ICertificate;
  LKey: IPrivateKey;
begin
  LRaised := False;
  LDetail := '';
  LResult := True;
  LCert := nil;
  LKey := nil;
  try
    LResult := TPKCS12Manager.LoadFromPKCS12(AP12Data, APassword, LCert, LKey);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  AssertTrue(AName + ' should return False', not LResult,
    'expected LoadFromPKCS12 to return False');
end;

procedure TestPKCS12HelpersShouldFailGracefullyWhenBIOHelpersAreUnavailable;
var
  LKeyPair: IKeyPairWithCertificate;
  LOptions: TPKCS12Options;
  LP12Data: TBytes;
  LOriginalBIONew: TBIO_new;
  LOriginalBIOSMem: TBIO_s_mem;
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIOFree: TBIO_free;
begin
  WriteLn;
  WriteLn('=== Advanced certificate PKCS12 BIO guard ===');

  if (not Assigned(BIO_new)) or
     (not Assigned(BIO_s_mem)) or
     (not Assigned(BIO_new_mem_buf)) or
     (not Assigned(BIO_free)) or
     (not Assigned(PKCS12_create)) or
     (not Assigned(i2d_PKCS12_bio)) or
     (not Assigned(d2i_PKCS12_bio)) or
     (not Assigned(PKCS12_parse)) or
     (not Assigned(PKCS12_free)) then
  begin
    MarkSkip('advanced certificate pkcs12 bio contract',
      'required baseline OpenSSL PKCS12/BIO helpers are unavailable');
    Exit;
  end;

  WarmupPKCS12Materials(LKeyPair, LOptions, LP12Data);

  LOriginalBIONew := BIO_new;
  LOriginalBIOSMem := BIO_s_mem;
  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  LOriginalBIOFree := BIO_free;

  BIO_new := nil;
  try
    AssertCreatePKCS12ControlledFailure(
      'CreatePKCS12 when BIO_new is unavailable',
      LKeyPair,
      LOptions
    );
  finally
    BIO_new := LOriginalBIONew;
  end;

  BIO_s_mem := nil;
  try
    AssertCreatePKCS12ControlledFailure(
      'CreatePKCS12 when BIO_s_mem is unavailable',
      LKeyPair,
      LOptions
    );
  finally
    BIO_s_mem := LOriginalBIOSMem;
  end;

  BIO_new_mem_buf := nil;
  try
    AssertLoadPKCS12SafeDegrade(
      'LoadFromPKCS12 when BIO_new_mem_buf is unavailable',
      LP12Data,
      PKCS12_PASSWORD
    );
  finally
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
  end;

  BIO_free := nil;
  try
    AssertCreatePKCS12ControlledFailure(
      'CreatePKCS12 when BIO_free is unavailable',
      LKeyPair,
      LOptions
    );
    AssertLoadPKCS12SafeDegrade(
      'LoadFromPKCS12 when BIO_free is unavailable',
      LP12Data,
      PKCS12_PASSWORD
    );
  finally
    BIO_free := LOriginalBIOFree;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Advanced Certificate PKCS12 BIO Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('advanced certificate pkcs12 bio contract',
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
      LoadPKCS12Module(GetCryptoLibHandle);
    end;

    if SkippedTests = 0 then
      TestPKCS12HelpersShouldFailGracefullyWhenBIOHelpersAreUnavailable;

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
