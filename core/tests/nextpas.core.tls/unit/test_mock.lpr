program test_mock;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  nextpas.core.thread.init,
  {$ENDIF}
  nextpas.core.test,
  test_base,
  test_openssl_core_mock,
  test_evp_cipher_mock,
  test_evp_digest_mock,
  test_hmac_mock,
  test_kdf_mock,
  test_rand_mock;

var
  LRunner: TSuiteRunner;
begin
  LRunner := TSuiteRunner.Create('Mock Unit Tests');
  LRunner.Add(DiscoverTests(TTestOpenSSLCoreMock.Create, 'OpenSSLCoreMock'));
  LRunner.Add(DiscoverTests(TTestEVPCipherMock.Create, 'EVPCipherMock'));
  LRunner.Add(DiscoverTests(TTestEVPDigestMock.Create, 'EVPDigestMock'));
  LRunner.Add(DiscoverTests(TTestHMACMock.Create, 'HMACMock'));
  LRunner.Add(DiscoverTests(TTestKDFMock.Create, 'KDFMock'));
  LRunner.Add(DiscoverTests(TTestRandomMock.Create, 'RandomMock'));
  LRunner.RunAll;
  LRunner.Summary;
  if LRunner.TotalFail > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
