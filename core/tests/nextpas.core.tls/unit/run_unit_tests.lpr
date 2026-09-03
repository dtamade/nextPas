program run_unit_tests;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  nextpas.core.thread.init,
  {$ENDIF}
  nextpas.core.test,
  test_base,
  test_openssl_core_unit;

var
  LRunner: TSuiteRunner;
begin
  WriteLn('=======================================');
  WriteLn('  nextpas.ssl 单元测试运行器');
  WriteLn('=======================================');
  WriteLn;

  LRunner := TSuiteRunner.Create('nextpas.ssl Unit Tests');
  LRunner.Add(DiscoverTests(TTestOpenSSLCore.Create, 'OpenSSLCore'));
  LRunner.RunAll;
  LRunner.Summary;

  if LRunner.TotalFail > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
