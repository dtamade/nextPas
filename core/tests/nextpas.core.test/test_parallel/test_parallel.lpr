{ test_parallel — Validates parallel test execution }
program test_parallel;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
  nextpas.core.test;

var
  GTestCounter: Integer = 0;

procedure TestParallelSimple1;
begin
  Check(True, 'test 1 passed');
  InterLockedIncrement(GTestCounter);
end;

procedure TestParallelSimple2;
begin
  Check(True, 'test 2 passed');
  InterLockedIncrement(GTestCounter);
end;

procedure TestParallelSimple3;
begin
  Check(True, 'test 3 passed');
  InterLockedIncrement(GTestCounter);
end;

procedure TestParallelSimple4;
begin
  Check(True, 'test 4 passed');
  InterLockedIncrement(GTestCounter);
end;

procedure TestParallelSimple5;
begin
  Check(True, 'test 5 passed');
  InterLockedIncrement(GTestCounter);
end;

procedure TestParallelSimple6;
begin
  Check(True, 'test 6 passed');
  InterLockedIncrement(GTestCounter);
end;

procedure TestParallelSimple7;
begin
  Check(True, 'test 7 passed');
  InterLockedIncrement(GTestCounter);
end;

procedure TestParallelSimple8;
begin
  Check(True, 'test 8 passed');
  InterLockedIncrement(GTestCounter);
end;

var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('Parallel Tests');
  LSuite.Test('p1', @TestParallelSimple1);
  LSuite.Test('p2', @TestParallelSimple2);
  LSuite.Test('p3', @TestParallelSimple3);
  LSuite.Test('p4', @TestParallelSimple4);
  LSuite.Test('p5', @TestParallelSimple5);
  LSuite.Test('p6', @TestParallelSimple6);
  LSuite.Test('p7', @TestParallelSimple7);
  LSuite.Test('p8', @TestParallelSimple8);

  if not LSuite.RunParallel(nil) then
  begin
    WriteLn;
    WriteLn(AnsiRed('PARALLEL TESTS FAILED'));
    Halt(1);
  end;

  WriteLn;
  WriteLn(AnsiBold('Test counter: '), GTestCounter);
  if GTestCounter <> 8 then
  begin
    WriteLn(AnsiRed('FAIL: expected 8 tests run, got '), GTestCounter);
    Halt(1);
  end;
  WriteLn;
  WriteLn(AnsiGreen('ALL PASSED'));
end.
