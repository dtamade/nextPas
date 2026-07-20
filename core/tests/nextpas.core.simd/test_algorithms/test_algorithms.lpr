program test_algorithms;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.simd,
  nextpas.core.simd.algorithms.testcase;

var
  LRunner: TSuiteRunner;
begin
  LRunner := TSuiteRunner.Create('Algorithms Tests');
  LRunner.Add(DiscoverTests(TTestCase_SimdAlgorithms.Create, 'TTestCase_SimdAlgorithms'));
  LRunner.RunAll;
  LRunner.Summary;
  if LRunner.TotalFail > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
