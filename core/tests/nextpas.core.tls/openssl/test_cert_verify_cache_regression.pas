program test_cert_verify_cache_regression;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.cert.verify.cache;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TestCert: PX509 = nil;

procedure LogPass(const AMessage: string);
begin
  Inc(TestsPassed);
  WriteLn('[PASS] ', AMessage);
end;

procedure LogFail(const AMessage: string);
begin
  Inc(TestsFailed);
  WriteLn('[FAIL] ', AMessage);
end;

function LoadTestCert: PX509;
var
  Bio: PBIO;
begin
  Result := nil;

  if not Assigned(BIO_new_file) then
    Exit;
  if not Assigned(PEM_read_bio_X509) then
    Exit;

  Bio := BIO_new_file('tests/certificate/test_certs/signer_cert.pem', 'r');
  if Bio = nil then
    Exit;
  try
    Result := PEM_read_bio_X509(Bio, nil, nil, nil);
  finally
    if Assigned(BIO_free) then
      BIO_free(Bio);
  end;
end;

procedure Test_NilCertificateIsSafe;
var
  Cache: TCertVerifyCache;
  Res: TCertVerifyResult;
  Hits, Misses, Size: Int64;
begin
  WriteLn;
  WriteLn('=== Nil certificate safety ===');

  Cache := TCertVerifyCache.Create(16, 60);
  try
    if not Cache.TryGet(nil, Res) then
      LogPass('TryGet(nil) returns false')
    else
      LogFail('TryGet(nil) should return false');

    Res.Valid := True;
    Res.ErrorCode := 0;
    Res.ErrorMessage := '';
    Res.VerifiedAt := Now;
    Cache.Put(nil, Res);

    Cache.GetStats(Hits, Misses, Size);
    if Size = 0 then
      LogPass('Put(nil) does not add cache entry')
    else
      LogFail('Put(nil) should not add cache entry');
  finally
    Cache.Free;
  end;
end;

procedure Test_FingerprintDeterminism;
var
  Cache: TCertVerifyCache;
  Res, Got: TCertVerifyResult;
  Hits, Misses, Size: Int64;
begin
  WriteLn;
  WriteLn('=== Fingerprint determinism ===');

  if TestCert = nil then
  begin
    LogFail('Test certificate is nil');
    Exit;
  end;

  Cache := TCertVerifyCache.Create(16, 60);
  try
    Res.Valid := True;
    Res.ErrorCode := 0;
    Res.ErrorMessage := '';
    Res.VerifiedAt := Now;

    Cache.Put(TestCert, Res);
    Cache.GetStats(Hits, Misses, Size);
    if Size = 1 then
      LogPass('Put(cert) adds one cache entry')
    else
      LogFail(Format('Put(cert) expected size=1, got %d', [Size]));

    if Cache.TryGet(TestCert, Got) and Got.Valid then
      LogPass('TryGet(cert) hits and returns stored result')
    else
      LogFail('TryGet(cert) should hit after Put(cert)');

    Cache.GetStats(Hits, Misses, Size);
    if Hits >= 1 then
      LogPass('Hit counter increments after TryGet(cert)')
    else
      LogFail('Hit counter did not increment');

  finally
    Cache.Free;
  end;
end;

function InitializeOpenSSLForTest: Boolean;
var
  CryptoLib: TLibHandle;
begin
  Result := False;

  try
    LoadOpenSSLCore;

    CryptoLib := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
    if CryptoLib = NilHandle then
      Exit;

    LoadOpenSSLBIO;
    LoadOpenSSLX509;
    if not LoadOpenSSLPEM(CryptoLib) then
      Exit;
    if not LoadEVP(CryptoLib) then
      Exit;

    Result := True;
  except
    on E: Exception do
    begin
      WriteLn('[FAIL] OpenSSL init exception: ', E.Message);
      Result := False;
    end;
  end;
end;

begin
  WriteLn('============================================');
  WriteLn('Cert Verify Cache Regression Test');
  WriteLn('============================================');

  if not InitializeOpenSSLForTest then
  begin
    WriteLn('[FAIL] Failed to initialize OpenSSL modules');
    Halt(1);
  end;

  TestCert := LoadTestCert;
  if TestCert = nil then
  begin
    WriteLn('[FAIL] Failed to load test certificate');
    Halt(1);
  end;

  try
    Test_NilCertificateIsSafe;
    Test_FingerprintDeterminism;
  finally
    if Assigned(X509_free) and (TestCert <> nil) then
      X509_free(TestCert);
    UnloadOpenSSLCore;
  end;

  WriteLn;
  WriteLn('============================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('============================================');

  if TestsFailed = 0 then
  begin
    WriteLn('[OK] ALL TESTS PASSED');
    ExitCode := 0;
  end
  else
  begin
    WriteLn('[ERROR] SOME TESTS FAILED');
    ExitCode := 1;
  end;
end.

