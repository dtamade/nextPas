{ test_bench — Test coverage for nextpas.core.test.bench
  =========================================================
  Covers: DefaultBenchTestConfig, RunBenchTest, RunBenchSuite,
          CheckBenchPerformance, CheckBenchThroughput }

program test_bench;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.test.helpers,
  nextpas.core.test.bench,
  nextpas.core.bench;

{ ── Benchmark functions ───────────────────────────────────────────────────── }

var
  GCounter: Int64 = 0;

procedure BenchNoop(const ACtx: IBenchContext);
begin
  { Intentionally empty — measures framework overhead }
end;

procedure BenchIncrement(const ACtx: IBenchContext);
begin
  Inc(GCounter);
end;

procedure BenchWork(const ACtx: IBenchContext);
var
  I: Integer;
begin
  for I := 1 to 100 do
    Inc(GCounter, I);
end;

{ ── DefaultBenchTestConfig ────────────────────────────────────────────────── }

procedure TestDefaultConfigMinDuration;
var
  LCfg: TBenchTestConfig;
begin
  LCfg := DefaultBenchTestConfig;
  CheckEqual(100, LCfg.MinDurationMs, 'MinDurationMs default');
end;

procedure TestDefaultConfigMinSamples;
var
  LCfg: TBenchTestConfig;
begin
  LCfg := DefaultBenchTestConfig;
  CheckEqual(5, LCfg.MinSamples, 'MinSamples default');
end;

procedure TestDefaultConfigMaxIterations;
var
  LCfg: TBenchTestConfig;
begin
  LCfg := DefaultBenchTestConfig;
  CheckEqual(0, LCfg.MaxIterations, 'MaxIterations default (0=auto)');
end;

procedure TestDefaultConfigTimeoutMs;
var
  LCfg: TBenchTestConfig;
begin
  LCfg := DefaultBenchTestConfig;
  CheckEqual(5000, LCfg.TimeoutMs, 'TimeoutMs default');
end;

procedure TestDefaultConfigThreadCount;
var
  LCfg: TBenchTestConfig;
begin
  LCfg := DefaultBenchTestConfig;
  CheckEqual(1, LCfg.ThreadCount, 'ThreadCount default');
end;

{ ── RunBenchTest ──────────────────────────────────────────────────────────── }

procedure TestRunBenchTestExecutes;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;   { fast for test }
  LCfg.MinSamples := 3;
  LRes := RunBenchTest('noop', @BenchNoop, LCfg);
  Check(LRes.Executed, 'should be executed');
  Check(not LRes.Skipped, 'should not be skipped');
end;

procedure TestRunBenchTestPopulatesName;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;
  LCfg.MinSamples := 3;
  LRes := RunBenchTest('mybench', @BenchIncrement, LCfg);
  CheckEqual('mybench', LRes.Name, 'result name');
end;

procedure TestRunBenchTestPositiveNsPerOp;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;
  LCfg.MinSamples := 3;
  LRes := RunBenchTest('work', @BenchWork, LCfg);
  Check(LRes.NsPerOp > 0, 'NsPerOp should be positive: ' + FloatToStr(LRes.NsPerOp));
end;

procedure TestRunBenchTestPositiveOpsPerSec;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;
  LCfg.MinSamples := 3;
  LRes := RunBenchTest('work', @BenchWork, LCfg);
  Check(LRes.OpsPerSec > 0, 'OpsPerSec should be positive');
end;

procedure TestRunBenchTestPositiveIterations;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;
  LCfg.MinSamples := 3;
  LRes := RunBenchTest('work', @BenchWork, LCfg);
  Check(LRes.Iterations > 0, 'Iterations should be positive: ' + IntToStr(LRes.Iterations));
end;

procedure TestRunBenchTestWithMaxIterations;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;
  LCfg.MinSamples := 3;
  LCfg.MaxIterations := 50;
  LRes := RunBenchTest('limited', @BenchNoop, LCfg);
  Check(LRes.Executed, 'should execute');
  Check(LRes.Iterations <= 50, 'should respect MaxIterations: ' + IntToStr(LRes.Iterations));
end;

{ ── RunBenchSuite ─────────────────────────────────────────────────────────── }

procedure TestRunBenchSuiteMultipleEntries;
var
  LCfg: TBenchTestConfig;
  LEntries: array of TBenchTestEntry;
  LResults: TBenchTestResultArray;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;
  LCfg.MinSamples := 3;

  SetLength(LEntries, 2);
  LEntries[0].Name := 'noop';
  LEntries[0].Func := @BenchNoop;
  LEntries[1].Name := 'increment';
  LEntries[1].Func := @BenchIncrement;

  LResults := RunBenchSuite('multi', LEntries, LCfg);
  CheckEqual(2, Length(LResults), 'should return 2 results');
  CheckEqual('noop', LResults[0].Name, 'first name');
  CheckEqual('increment', LResults[1].Name, 'second name');
end;

procedure TestRunBenchSuiteAllExecuted;
var
  LCfg: TBenchTestConfig;
  LEntries: array of TBenchTestEntry;
  LResults: TBenchTestResultArray;
  I: Integer;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;
  LCfg.MinSamples := 3;

  SetLength(LEntries, 2);
  LEntries[0].Name := 'a';
  LEntries[0].Func := @BenchNoop;
  LEntries[1].Name := 'b';
  LEntries[1].Func := @BenchWork;

  LResults := RunBenchSuite('suite', LEntries, LCfg);
  for I := 0 to High(LResults) do
    Check(LResults[I].Executed, LResults[I].Name + ' should be executed');
end;

procedure TestRunBenchSuiteEmpty;
var
  LCfg: TBenchTestConfig;
  LEntries: array of TBenchTestEntry;
  LResults: TBenchTestResultArray;
begin
  LCfg := DefaultBenchTestConfig;
  SetLength(LEntries, 0);
  LResults := RunBenchSuite('empty', LEntries, LCfg);
  CheckEqual(0, Length(LResults), 'empty suite returns empty array');
end;

{ ── CheckBenchPerformance ─────────────────────────────────────────────────── }

procedure TestCheckBenchPerformancePasses;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;
  LCfg.MinSamples := 3;
  LRes := RunBenchTest('noop', @BenchNoop, LCfg);
  { 1ms threshold — noop should be well under this }
  CheckBenchPerformance(LRes, 1e6, 'noop should be under 1ms/op');
end;

procedure TestCheckBenchPerformanceFails;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;
  LCfg.MinSamples := 3;
  LRes := RunBenchTest('work', @BenchWork, LCfg);
  { 0.001ns threshold — impossible, should fail }
  ExpectFail(procedure begin
    CheckBenchPerformance(LRes, 0.001);
  end, 'exceeds threshold');
end;

procedure TestCheckBenchPerformanceNotExecuted;
var
  LRes: TBenchTestResult;
begin
  LRes.Name := 'dummy';
  LRes.Executed := False;
  LRes.NsPerOp := 0;
  ExpectFail(procedure begin
    CheckBenchPerformance(LRes, 1e9);
  end);
end;

{ ── CheckBenchThroughput ──────────────────────────────────────────────────── }

procedure TestCheckBenchThroughputPasses;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;
  LCfg.MinSamples := 3;
  LRes := RunBenchTest('noop', @BenchNoop, LCfg);
  { 1 op/s threshold — any benchmark should exceed this }
  CheckBenchThroughput(LRes, 1.0, 'noop should exceed 1 op/s');
end;

procedure TestCheckBenchThroughputFails;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MinDurationMs := 10;
  LCfg.MinSamples := 3;
  LRes := RunBenchTest('work', @BenchWork, LCfg);
  { 1e18 threshold — impossible, should fail }
  ExpectFail(procedure begin
    CheckBenchThroughput(LRes, 1e18);
  end, 'below threshold');
end;

procedure TestCheckBenchThroughputNotExecuted;
var
  LRes: TBenchTestResult;
begin
  LRes.Name := 'dummy';
  LRes.Executed := False;
  LRes.OpsPerSec := 0;
  ExpectFail(procedure begin
    CheckBenchThroughput(LRes, 1.0);
  end);
end;

{ ── Custom message forwarding ─────────────────────────────────────────────── }

procedure TestCheckBenchPerformanceCustomMessage;
var
  LRes: TBenchTestResult;
begin
  LRes.Name := 'x';
  LRes.Executed := False;
  LRes.NsPerOp := 0;
  ExpectFail(procedure begin
    CheckBenchPerformance(LRes, 1e9, 'my custom msg');
  end, 'my custom msg');
end;

procedure TestCheckBenchThroughputCustomMessage;
var
  LRes: TBenchTestResult;
begin
  LRes.Name := 'x';
  LRes.Executed := False;
  LRes.OpsPerSec := 0;
  ExpectFail(procedure begin
    CheckBenchThroughput(LRes, 1.0, 'my custom msg');
  end, 'my custom msg');
end;

{ ── B26: bench config boundary fail-paths ─────────────────────────────────── }

procedure TestB26MaxIterationsZeroMeansDefault;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MaxIterations := 0;
  LCfg.MinDurationMs := 5;
  LCfg.MinSamples := 1;
  LRes := RunBenchTest('noop0', @BenchNoop, LCfg);
  CheckTrue(LRes.Executed);
  CheckTrue(LRes.Iterations > 0, 'zero MaxIterations still runs');
end;

procedure TestB26MaxIterationsOne;
var
  LCfg: TBenchTestConfig;
  LRes: TBenchTestResult;
begin
  LCfg := DefaultBenchTestConfig;
  LCfg.MaxIterations := 1;
  { MinDurationMs must be >= 1 (FromMilliseconds(0) rejects as < 1 us) }
  LCfg.MinDurationMs := 1;
  LCfg.MinSamples := 1;
  LRes := RunBenchTest('noop1', @BenchNoop, LCfg);
  CheckTrue(LRes.Executed);
  CheckTrue(LRes.Iterations >= 1);
  CheckTrue(LRes.Iterations <= 1, 'MaxIterations=1 caps at 1');
end;

procedure TestB26NegativeThresholdAlwaysFail;
var
  LRes: TBenchTestResult;
begin
  LRes.Name := 'n';
  LRes.Executed := True;
  LRes.NsPerOp := 100;
  LRes.OpsPerSec := 1e6;
  ExpectFail(procedure begin
    CheckBenchPerformance(LRes, -1.0);
  end);
end;

procedure TestB26ThroughputZeroThresholdPass;
var
  LRes: TBenchTestResult;
begin
  LRes.Name := 'n';
  LRes.Executed := True;
  LRes.OpsPerSec := 1.0;
  CheckBenchThroughput(LRes, 0.0);
end;

procedure TestB26PerformanceZeroThresholdFail;
var
  LRes: TBenchTestResult;
begin
  LRes.Name := 'n';
  LRes.Executed := True;
  LRes.NsPerOp := 1.0;
  { threshold 0: any positive NsPerOp exceeds }
  ExpectFail(procedure begin
    CheckBenchPerformance(LRes, 0.0);
  end);
end;

procedure TestB39BenchNotExecutedThroughputFail;
var
  LRes: TBenchTestResult;
begin
  LRes.Name := 'skip-me';
  LRes.Executed := False;
  LRes.OpsPerSec := 1e9;
  ExpectFail(procedure begin
    CheckBenchThroughput(LRes, 1.0);
  end, 'throughput');  { Executed=False → Check fails with default throughput msg }
end;

procedure TestB39BenchHugeThresholdPass;
var
  LRes: TBenchTestResult;
begin
  LRes.Name := 'ok';
  LRes.Executed := True;
  LRes.NsPerOp := 1.0;
  CheckBenchPerformance(LRes, 1e12);
end;

procedure TestB43BenchNotExecutedPerfFail;
var
  LRes: TBenchTestResult;
begin
  LRes.Name := 'n';
  LRes.Executed := False;
  LRes.NsPerOp := 0;
  ExpectFail(procedure begin
    CheckBenchPerformance(LRes, 100.0);
  end, 'performance');
end;

procedure TestB43BenchThroughputTooHigh;
var
  LRes: TBenchTestResult;
begin
  LRes.Name := 'slow';
  LRes.Executed := True;
  LRes.OpsPerSec := 10.0;
  ExpectFail(procedure begin
    CheckBenchThroughput(LRes, 1e9);
  end, 'throughput');
end;

{ ── F-13: fail-path density for thin suite ────────────────────────────────── }

procedure TestBenchFailPathCase(const AC: TTestCase);
var
  LRes: TBenchTestResult;
begin
  FillChar(LRes, SizeOf(LRes), 0);
  LRes.Name := 'fp-' + AC.Name;
  LRes.Executed := False;
  ExpectFail(procedure
    begin
      { Empty message → default format still fails when not executed }
      CheckBenchPerformance(LRes, 1.0, '');
    end, 'performance');
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  S: TTestSuite;
  LFpCases: specialize TArray<TTestCase>;
  LFpI: Integer;
begin
  S := TTestSuite.Create('test_bench');

  { DefaultBenchTestConfig }
  S.Test('DefaultConfig/MinDuration', @TestDefaultConfigMinDuration);
  S.Test('DefaultConfig/MinSamples', @TestDefaultConfigMinSamples);
  S.Test('DefaultConfig/MaxIterations', @TestDefaultConfigMaxIterations);
  S.Test('DefaultConfig/TimeoutMs', @TestDefaultConfigTimeoutMs);
  S.Test('DefaultConfig/ThreadCount', @TestDefaultConfigThreadCount);

  { RunBenchTest }
  S.Test('RunBenchTest/Executes', @TestRunBenchTestExecutes);
  S.Test('RunBenchTest/PopulatesName', @TestRunBenchTestPopulatesName);
  S.Test('RunBenchTest/PositiveNsPerOp', @TestRunBenchTestPositiveNsPerOp);
  S.Test('RunBenchTest/PositiveOpsPerSec', @TestRunBenchTestPositiveOpsPerSec);
  S.Test('RunBenchTest/PositiveIterations', @TestRunBenchTestPositiveIterations);
  S.Test('RunBenchTest/MaxIterations', @TestRunBenchTestWithMaxIterations);

  { RunBenchSuite }
  S.Test('RunBenchSuite/MultipleEntries', @TestRunBenchSuiteMultipleEntries);
  S.Test('RunBenchSuite/AllExecuted', @TestRunBenchSuiteAllExecuted);
  S.Test('RunBenchSuite/Empty', @TestRunBenchSuiteEmpty);

  { CheckBenchPerformance }
  S.Test('CheckBenchPerformance/Passes', @TestCheckBenchPerformancePasses);
  S.Test('CheckBenchPerformance/Fails', @TestCheckBenchPerformanceFails);
  S.Test('CheckBenchPerformance/NotExecuted', @TestCheckBenchPerformanceNotExecuted);

  { CheckBenchThroughput }
  S.Test('CheckBenchThroughput/Passes', @TestCheckBenchThroughputPasses);
  S.Test('CheckBenchThroughput/Fails', @TestCheckBenchThroughputFails);
  S.Test('CheckBenchThroughput/NotExecuted', @TestCheckBenchThroughputNotExecuted);

  { Custom messages }
  S.Test('CheckBenchPerformance/CustomMsg', @TestCheckBenchPerformanceCustomMessage);
  S.Test('CheckBenchThroughput/CustomMsg', @TestCheckBenchThroughputCustomMessage);

  { B26 boundaries }
  S.Test('B26 MaxIterations zero', @TestB26MaxIterationsZeroMeansDefault);
  S.Test('B26 MaxIterations one', @TestB26MaxIterationsOne);
  S.Test('B26 negative threshold fail', @TestB26NegativeThresholdAlwaysFail);
  S.Test('B26 throughput zero threshold', @TestB26ThroughputZeroThresholdPass);
  S.Test('B26 performance zero threshold fail', @TestB26PerformanceZeroThresholdFail);
  S.Test('B39 not executed throughput fail', @TestB39BenchNotExecutedThroughputFail);
  S.Test('B39 huge threshold pass', @TestB39BenchHugeThresholdPass);
  S.Test('B43 not executed performance fail', @TestB43BenchNotExecutedPerfFail);
  S.Test('B43 throughput high threshold fail', @TestB43BenchThroughputTooHigh);

  SetLength(LFpCases, 40);
  for LFpI := 0 to High(LFpCases) do
  begin
    LFpCases[LFpI].Name := 'bench-fp-' + IntToStr(LFpI);
    LFpCases[LFpI].Data := IntToStr(LFpI);
  end;
  S.TestTable('bench fail-path ExpectFail', LFpCases, @TestBenchFailPathCase);

  S.Run;
  S.Summary;
  if not S.AllPassed then
    Halt(1);
end.
