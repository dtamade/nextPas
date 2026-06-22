{ test_parallel — Validates parallel test execution }
program test_parallel;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  cthreads,
  SysUtils,
  nextpas.core.test;

var
  GTestCounter: Integer = 0;

procedure TestParallelSimple;
begin
  Check(True, 'simple parallel pass');
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

{ ── F09: Parallel lifecycle failure tests ─────────────────────────────────── }

procedure TestParallelBeforeEachFail;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ParBeforeEachFail');
  LSuite.OnBeforeEach(procedure begin raise Exception.Create('beforeEach boom'); end);
  LSuite.Test('t1', @TestParallelPassA);
  LSuite.Test('t2', @TestParallelPassB);
  { RunParallel should handle beforeEach failure gracefully }
  LSuite.RunParallel(nil);
  if LSuite.LastFail < 1 then
  begin
    WriteLn(AnsiRed('FAIL: expected at least 1 failure from beforeEach'));
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ Parallel beforeEach failure'));
end;

procedure TestParallelSetupFail;
var
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('ParSetupFail');
  LSuite.SetSetup(procedure begin raise Exception.Create('setup boom'); end);
  LSuite.Test('t1', @TestParallelPassA);
  LSuite.Test('t2', @TestParallelPassB);
  { Setup failure should skip all tests }
  LSuite.RunParallel(nil);
  if LSuite.LastSkip < 2 then
  begin
    WriteLn(AnsiRed('FAIL: expected 2 skips from setup failure, got '), LSuite.LastSkip);
    Halt(1);
  end;
  if LSuite.LastFail <> 1 then
  begin
    WriteLn(AnsiRed('FAIL: expected LastFail=1 for setup failure, got '), LSuite.LastFail);
    Halt(1);
  end;
  WriteLn(AnsiGreen('  ✓ Parallel setup failure'));
end;

var
  LSuite: TTestSuite;
  LFailSuite, LSkipSuite: TTestSuite;
  LRunner: TTestRunner;
begin
  LSuite := TTestSuite.Create('Parallel Tests');
  LSuite.Test('p1', @TestParallelSimple);
  LSuite.Test('p2', @TestParallelSimple);
  LSuite.Test('p3', @TestParallelSimple);
  LSuite.Test('p4', @TestParallelSimple);
  LSuite.Test('p5', @TestParallelSimple);
  LSuite.Test('p6', @TestParallelSimple);
  LSuite.Test('p7', @TestParallelSimple);
  LSuite.Test('p8', @TestParallelSimple);

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
  if LFailSuite.LastFail < 1 then
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
  if LSkipSuite.LastSkip < 2 then
  begin
    WriteLn(AnsiRed('FAIL: expected at least 2 skips (static + worker), got '), LSkipSuite.LastSkip);
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

  { ── F08: RunAllParallel aggregation ───────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── F08: RunAllParallel Aggregation ───'));
  begin
    LRunner := TTestRunner.Create('Aggregation Runner');
    { Suite A: 3 pass + 1 skip + 1 fail = 5 }
    LSkipSuite := TTestSuite.Create('Suite A');
    LSkipSuite.Test('a1', @TestParallelPassA);
    LSkipSuite.Test('a2', @TestParallelPassB);
    LSkipSuite.Test('a3', @TestParallelSimple);
    LSkipSuite.Skip('a4', 'deferred');
    LSkipSuite.Test('a5', @TestParallelFail);
    LRunner.Add(LSkipSuite);
    { Suite B: 2 pass = 2 }
    LFailSuite := TTestSuite.Create('Suite B');
    LFailSuite.Test('b1', @TestParallelSimple);
    LFailSuite.Test('b2', @TestParallelSimple);
    LRunner.Add(LFailSuite);
    if LRunner.RunAllParallel(nil) then
    begin
      WriteLn(AnsiRed('FAIL: RunAllParallel should return False (suite A has failure)'));
      Halt(1);
    end;
    { TotalPass should be 5 (3 from A + 2 from B) }
    if LRunner.TotalPass <> 5 then
    begin
      WriteLn(AnsiRed('FAIL: Expected TotalPass=5, got '), LRunner.TotalPass);
      Halt(1);
    end;
    { TotalFail should be 1 (from A) }
    if LRunner.TotalFail <> 1 then
    begin
      WriteLn(AnsiRed('FAIL: Expected TotalFail=1, got '), LRunner.TotalFail);
      Halt(1);
    end;
    { TotalSkip should be 1 (from A) }
    if LRunner.TotalSkip <> 1 then
    begin
      WriteLn(AnsiRed('FAIL: Expected TotalSkip=1, got '), LRunner.TotalSkip);
      Halt(1);
    end;
    WriteLn(AnsiGreen('  ✓ RunAllParallel aggregation'));
  end;

  WriteLn;
  WriteLn(AnsiGreen('ALL PARALLEL TESTS PASSED'));

  { ── F09: Parallel lifecycle failures ───────────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── F09: Parallel Lifecycle Failure Tests ───'));
  TestParallelBeforeEachFail;
  TestParallelSetupFail;

  WriteLn;
  WriteLn(AnsiGreen('ALL LIFECYCLE TESTS PASSED'));
end.
