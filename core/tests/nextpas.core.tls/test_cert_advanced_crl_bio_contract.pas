program test_cert_advanced_crl_bio_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.cert.advanced,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem;

const
  VALID_CRL_PEM =
    '-----BEGIN X509 CRL-----'#10 +
    'MIIBjTB3AgEBMA0GCSqGSIb3DQEBCwUAMDQxEDAOBgNVBAMMB1Rlc3QgQ0ExEzAR'#10 +
    'BgNVBAoMCmZhZmFmYS5zc2wxCzAJBgNVBAYTAlVTFw0yNjAzMjAxNTI5NDZaFw0y'#10 +
    'NjA0MTkxNTI5NDZaoA8wDTALBgNVHRQEBAICEAAwDQYJKoZIhvcNAQELBQADggEB'#10 +
    'ACLaEDdVdaNeX3pTi8a2QjBKXDhZhr3sphOOr+4jGq2BrM4nd3Y/AzSLeykWtch7'#10 +
    'tWtNT0BoNpPP63zD7qkUx3BS9qT/ATFuikWflP2cG3NzMXPLzjdcVF2LJCJf64VI'#10 +
    'FOjEW1F6MDGp0Rciwjj9X52IePexvrmGqHVnDsvn1KVWNEiIP4THom01tUeHn186'#10 +
    '8uLIjDgJ4DD7rSbR+OH1H6d8Dhh14yGBz6xVMA/BaCzTcRKH4VpUKgrw6wPKZAIy'#10 +
    'RAAm1DGds5Z9gTqELwYJVHwv2UpdESsCGIYs7kOuyj+2MYyHhGNEPbUer3IZ7OZN'#10 +
    'A0+1F8BNBBFon7Ehk2j/F6c='#10 +
    '-----END X509 CRL-----';

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

procedure WarmupCRLLoad;
var
  LManager: ICRLManager;
begin
  LManager := CreateCRLManager;
  if LManager = nil then
    raise Exception.Create('failed to create CRL manager for warmup');
  LManager.LoadFromPEM(VALID_CRL_PEM);
end;

procedure AssertCRLLoadControlledFailure(const AName: string);
var
  LManager: ICRLManager;
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
begin
  LManager := CreateCRLManager;
  if LManager = nil then
    raise Exception.Create('failed to create CRL manager');

  LRaised := False;
  LControlled := False;
  LDetail := '';
  try
    LManager.LoadFromPEM(VALID_CRL_PEM);
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLException;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected LoadFromPEM(...) to fail');
  AssertTrue(AName + ' should raise controlled ESSLException', LControlled, LDetail);
end;

procedure TestCRLLoadShouldFailGracefullyWhenBIOHelpersAreUnavailable;
var
  LOriginalBIONewMemBuf: TBIO_new_mem_buf;
  LOriginalBIOFree: TBIO_free;
begin
  WriteLn;
  WriteLn('=== Advanced certificate CRL BIO guard ===');

  if (not Assigned(BIO_new_mem_buf)) or
     (not Assigned(BIO_free)) or
     (not Assigned(PEM_read_bio_X509_CRL)) then
  begin
    MarkSkip('advanced certificate crl bio contract',
      'required baseline OpenSSL CRL/BIO helpers are unavailable');
    Exit;
  end;

  WarmupCRLLoad;

  LOriginalBIONewMemBuf := BIO_new_mem_buf;
  BIO_new_mem_buf := nil;
  try
    AssertCRLLoadControlledFailure(
      'LoadFromPEM when BIO_new_mem_buf is unavailable'
    );
  finally
    BIO_new_mem_buf := LOriginalBIONewMemBuf;
  end;

  LOriginalBIOFree := BIO_free;
  BIO_free := nil;
  try
    AssertCRLLoadControlledFailure(
      'LoadFromPEM when BIO_free is unavailable'
    );
  finally
    BIO_free := LOriginalBIOFree;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Advanced Certificate CRL BIO Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('advanced certificate crl bio contract',
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
      TestCRLLoadShouldFailGracefullyWhenBIOHelpersAreUnavailable;

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
