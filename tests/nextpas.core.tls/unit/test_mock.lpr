program test_mock;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils,
  fpcunit, testregistry, consoletestrunner,
  // Test units
  test_base,
  test_openssl_core_mock,
  test_evp_cipher_mock,
  test_evp_digest_mock,
  test_hmac_mock,
  test_kdf_mock,
  test_rand_mock;

var
  App: TTestRunner;
begin
  DefaultFormat := fPlain;
  DefaultRunAllTests := True;
  
  App := TTestRunner.Create(nil);
  try
    App.Initialize;
    App.Title := 'Mock Unit Tests';
    App.Run;
  finally
    App.Free;
  end;
end.
