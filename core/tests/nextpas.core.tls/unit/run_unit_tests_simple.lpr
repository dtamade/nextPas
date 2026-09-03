program run_unit_tests_simple;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  nextpas.core.thread.init,
  {$ENDIF}
  nextpas.core.test,
  test_base,
  test_openssl_core_unit,
  test_openssl_async_unit;

var
  LRunner: TSuiteRunner;
begin
  LRunner := TSuiteRunner.Create('nextpas.ssl Unit Tests');
  LRunner.Add(DiscoverTests(TTestOpenSSLCore.Create, 'OpenSSLCore'));
  LRunner.Add(DiscoverTests(TTestOpenSSLAsync.Create, 'OpenSSLAsync'));
  LRunner.RunAll;
  LRunner.Summary;
  if LRunner.TotalFail > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
