program run_tests;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  nextpas.core.thread.init,
  {$ENDIF}
  Classes, SysUtils,
  nextpas.core.test,
  test_base,
  test_openssl_core_unit;

var
  LRunner: TSuiteRunner;
begin
  LRunner := TSuiteRunner.Create('fafafa.ssl Tests');
  LRunner.Add(DiscoverTests(TTestOpenSSLCore.Create, 'OpenSSLCore'));
  LRunner.RunAll;
  LRunner.Summary;
  if LRunner.TotalFail > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
