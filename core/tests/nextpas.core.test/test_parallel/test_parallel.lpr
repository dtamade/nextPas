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

{ ── B5.10: Additional parallel tests ─────────────────────────────────────── }

procedure TestParallelFail;
begin
  Check(False, 'intentional parallel failure');
end;

procedure TestParallelSkip;
begin
  Skip('intentionally skipped in parallel');
end;

procedure TestParallelPassA;
begin
  Check(True);
end;

procedure TestParallelPassB;
begin
  Check(True);
end;

var
  LSuite: TTestSuite;
  LFailSuite, LSkipSuite: TTestSuite;
  LRunner: TTestRunner;
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

  { ── B5.10: Parallel with failure ───────────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── B5.10: Parallel Failure/Skip Tests ───'));
  LFailSuite := TTestSuite.Create('Parallel Failure');
  LFailSuite.Test('pass', @TestParallelPassA);
  LFailSuite.Test('fail', @TestParallelFail);
  if LFailSuite.RunParallel(nil) then
  begin
    WriteLn(AnsiRed('FAIL: suite with failing test should return False'));
    Halt(1);
  end;
  if LFailSuite.FLastFail < 1 then
  begin
    WriteLn(AnsiRed('FAIL: expected at least 1 failure'));
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ Parallel with failure'));

  { ── B5.10: Parallel with skip ─────────────────────────────────────────── }
  LSkipSuite := TTestSuite.Create('Parallel Skip');
  LSkipSuite.Test('pass', @TestParallelPassB);
  LSkipSuite.Skip('skip me', 'reason');
  LSkipSuite.Test('skip in worker', @TestParallelSkip);
  if not LSkipSuite.RunParallel(nil) then
  begin
    WriteLn(AnsiRed('FAIL: suite with skip should still return True'));
    Halt(1);
  end;
  if LSkipSuite.FLastSkip < 2 then
  begin
    WriteLn(AnsiRed('FAIL: expected at least 2 skips (static + worker), got '), LSkipSuite.FLastSkip);
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ Parallel with skip'));

  { ── B5.10: RunAllParallel ─────────────────────────────────────────────── }
  LRunner := TTestRunner.Create('Parallel Runner');
  LRunner.Add(LSkipSuite);
  LRunner.Add(LFailSuite);
  if LRunner.RunAllParallel(nil) then
  begin
    WriteLn(AnsiRed('FAIL: RunAllParallel with failure suite should return False'));
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ RunAllParallel'));

  WriteLn;
  WriteLn(AnsiGreen('ALL PARALLEL TESTS PASSED'));
end.
