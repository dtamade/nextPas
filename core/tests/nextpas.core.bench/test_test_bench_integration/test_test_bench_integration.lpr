{*
 * nextpas.core.test.bench - Integration Tests
 *
 * 验证 test 框架与 bench 模块的集成。
 *}

program test_test_bench;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.test.bench,
  nextpas.core.bench,
  nextpas.core.time.base;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(GTestCount);
  if ACondition then
    Inc(GPassCount)
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

{*
 * 简单基准函数
 *}
procedure BenchExample(const ACtx: IBenchContext);
var
  LSum: Int64;
  I: Integer;
begin
  LSum := 0;
  for I := 1 to 1000 do
    Inc(LSum, I);
  if LSum < 0 then
    WriteLn('Impossible');
end;

{*
 * 测试 RunBenchTest
 *}
procedure Test_RunBenchTest;
var
  LResult: TBenchTestResult;
  LConfig: TBenchTestConfig;
begin
  WriteLn('  + run_bench_test');

  LConfig := DefaultBenchTestConfig;
  LConfig.MinDurationMs := 50;
  LConfig.MinSamples := 3;

  LResult := RunBenchTest('SimpleBench', @BenchExample, LConfig);

  Check(LResult.Executed, 'Benchmark should be executed');
  Check(not LResult.Skipped, 'Benchmark should not be skipped');
  Check(LResult.NsPerOp > 0, 'ns/op should be > 0');
  Check(LResult.OpsPerSec > 0, 'ops/s should be > 0');
  Check(LResult.Iterations > 0, 'Iterations should be > 0');
end;

{*
 * 测试 RunBenchSuite
 *}
procedure Test_RunBenchSuite;
var
  LEntries: array[0..2] of TBenchTestEntry;
  LResults: TBenchTestResultArray;
  LConfig: TBenchTestConfig;
begin
  WriteLn('  + run_bench_suite');

  LEntries[0].Name := 'Bench1';
  LEntries[0].Func := @BenchExample;
  LEntries[1].Name := 'Bench2';
  LEntries[1].Func := @BenchExample;
  LEntries[2].Name := 'Bench3';
  LEntries[2].Func := @BenchExample;

  LConfig := DefaultBenchTestConfig;
  LConfig.MinDurationMs := 50;
  LConfig.MinSamples := 3;

  LResults := RunBenchSuite('SuiteTest', LEntries, LConfig);

  Check(Length(LResults) = 3, 'Should have 3 results');
  Check(LResults[0].Executed, 'Bench1 should be executed');
  Check(LResults[1].Executed, 'Bench2 should be executed');
  Check(LResults[2].Executed, 'Bench3 should be executed');
end;

{*
 * 测试 CheckBenchPerformance
 *}
procedure Test_CheckBenchPerformance;
var
  LResult: TBenchTestResult;
  LConfig: TBenchTestConfig;
begin
  WriteLn('  + check_bench_performance');

  LConfig := DefaultBenchTestConfig;
  LConfig.MinDurationMs := 50;
  LConfig.MinSamples := 3;

  LResult := RunBenchTest('PerfCheck', @BenchExample, LConfig);

  { 设置一个宽松的阈值（1 微秒 = 1000 ns） }
  CheckBenchPerformance(LResult, 10000.0, 'Performance should be under 10us');
end;

{*
 * 测试 CheckBenchThroughput
 *}
procedure Test_CheckBenchThroughput;
var
  LResult: TBenchTestResult;
  LConfig: TBenchTestConfig;
begin
  WriteLn('  + check_bench_throughput');

  LConfig := DefaultBenchTestConfig;
  LConfig.MinDurationMs := 50;
  LConfig.MinSamples := 3;

  LResult := RunBenchTest('ThroughputCheck', @BenchExample, LConfig);

  { 设置一个宽松的阈值（100 ops/s） }
  CheckBenchThroughput(LResult, 100.0, 'Throughput should be > 100 ops/s');
end;

{*
 * 测试并行基准
 *}
procedure Test_ParallelBench;
var
  LResult: TBenchTestResult;
  LConfig: TBenchTestConfig;
begin
  WriteLn('  + parallel_bench');

  LConfig := DefaultBenchTestConfig;
  LConfig.MinDurationMs := 50;
  LConfig.MinSamples := 3;
  LConfig.ThreadCount := 2;

  LResult := RunBenchTest('ParallelBench', @BenchExample, LConfig);

  Check(LResult.Executed, 'Parallel benchmark should be executed');
  Check(LResult.NsPerOp > 0, 'ns/op should be > 0');
end;

{*
 * 主测试套件
 *}
begin
  WriteLn('=== nextpas.core.test.bench Integration Tests ===');
  WriteLn;

  Test_RunBenchTest;
  Test_RunBenchSuite;
  Test_CheckBenchPerformance;
  Test_CheckBenchThroughput;
  Test_ParallelBench;

  WriteLn;
  WriteLn(Format('  %d passed, %d failed, 0 skipped', [GPassCount, GFailCount]));
  WriteLn('--- test-bench-integration ---');
  WriteLn(Format('  Total tests: %d', [GTestCount]));
  WriteLn(Format('  Passed: %d, Failed: %d, Skipped: 0', [GPassCount, GFailCount]));
  WriteLn;

  if GFailCount > 0 then
  begin
    WriteLn('=== INTEGRATION TESTS FAILED ===');
    ExitCode := 1;
  end
  else
    WriteLn('=== All Integration Tests Passed ===');
end.
