program nextpas.core.simd.cpuinfo.test;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

uses
  {$IFDEF UNIX}
  nextpas.core.thread.init,
  {$ENDIF}
  nextpas.core.test,
  nextpas.core.simd.cpuinfo.testcase,
  nextpas.core.simd.cpuinfo.lazy.testcase
  ;

var
  LRunner: TSuiteRunner;
begin
  LRunner := TSuiteRunner.Create('nextpas.core.simd.cpuinfo tests');
  LRunner.Add(DiscoverTests(TTestFixture_Global.Create, 'TTestFixture_Global'));
  LRunner.Add(DiscoverTests(TTestFixture_ThreadSafety.Create, 'TTestFixture_ThreadSafety'));
  LRunner.Add(DiscoverTests(TTestFixture_PlatformSpecific.Create, 'TTestFixture_PlatformSpecific'));
  LRunner.Add(DiscoverTests(TTestFixture_ErrorHandling.Create, 'TTestFixture_ErrorHandling'));
  LRunner.Add(DiscoverTests(TTestFixture_LazyCPUInfo.Create, 'TTestFixture_LazyCPUInfo'));
  LRunner.RunAll;
  LRunner.Summary;
  if LRunner.TotalFail > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
