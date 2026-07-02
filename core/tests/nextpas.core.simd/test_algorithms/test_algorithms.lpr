program test_algorithms;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  Classes,
  fpcunit, testregistry, consoletestrunner,
  nextpas.core.simd,
  nextpas.core.simd.algorithms.testcase;

var
  App: TTestRunner;
begin
  App := TTestRunner.Create(nil);
  try
    App.Initialize;
    App.Run;
  finally
    App.Free;
  end;
end.
