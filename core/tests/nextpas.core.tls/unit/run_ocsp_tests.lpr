program run_ocsp_tests;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  nextpas.core.thread.init,
  {$ENDIF}
  nextpas.core.test,
  test_ocsp_stapling;

var
  LRunner: TSuiteRunner;
begin
  WriteLn('=======================================');
  WriteLn('  OCSP Stapling 单元测试运行器');
  WriteLn('=======================================');
  WriteLn;

  LRunner := TSuiteRunner.Create('OCSP Stapling Tests');
  LRunner.Add(DiscoverTests(TOCSPCacheTest.Create, 'OCSPCache'));
  LRunner.Add(DiscoverTests(TOCSPStaplingConfigTest.Create, 'OCSPStaplingConfig'));
  LRunner.Add(DiscoverTests(TOCSPStaplingResultTest.Create, 'OCSPStaplingResult'));
  LRunner.Add(DiscoverTests(TOCSPStaplingClientTest.Create, 'OCSPStaplingClient'));
  LRunner.Add(DiscoverTests(TOCSPStaplingServerTest.Create, 'OCSPStaplingServer'));
  LRunner.Add(DiscoverTests(TOCSPStaplingManagerTest.Create, 'OCSPStaplingManager'));
  LRunner.RunAll;
  LRunner.Summary;

  if LRunner.TotalFail > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
