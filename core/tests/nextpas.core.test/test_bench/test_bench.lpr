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

{ ── v8.38: CheckBench* 判定矩阵 + config/suite 结构契约（B78 tranche 5） ──── }

function NextSegB(var ARest: string): string;
var
  LP: Integer;
begin
  LP := Pos('|', ARest);
  if LP = 0 then
  begin
    Result := ARest;
    ARest := '';
  end
  else
  begin
    Result := Copy(ARest, 1, LP - 1);
    ARest := Copy(ARest, LP + 1, Length(ARest));
  end;
end;

function BoolMark(AB: Boolean): string;
begin
  if AB then
    Result := 'T'
  else
    Result := 'F';
end;

procedure AppendBCase(var ACases: specialize TArray<TTestCase>;
  const AName, AData, AFlag: string);
var
  LIdx: Integer;
begin
  LIdx := Length(ACases);
  SetLength(ACases, LIdx + 1);
  ACases[LIdx].Name := AName;
  ACases[LIdx].Data := AData + '|' + AFlag;
end;

{ Data: kind|exec|skip|metricTenths|thrTenths|msg|want|flag
  kind: p=CheckBenchPerformance(NsPerOp<=thr), t=CheckBenchThroughput(OpsPerSec>=thr)
  metric/thr 以十分位整数编码（'25'=2.5，'-10'=-1.0），避免浮点字面量解析。
  msg: '-'=无自定义消息。want: 'pass' 或失败消息 exact（含 %.1f/%.0f 渲染）。
  锁定契约：Executed=False 指标达标也必败；Skipped 字段被判定完全忽略；
  <=/>= 闭边界；自定义消息完全覆盖默认（含 NotExecuted 场景）。 }
procedure RunBenchCheckCase(const AC: TTestCase);
var
  LRest, LKind, LMsgParam, LWant, LFlag, LGotMsg: string;
  LRes: TBenchTestResult;
  LMetric, LThr: Double;
  LRaised: Boolean;
begin
  LRest := AC.Data;
  LKind := NextSegB(LRest);
  LRes := Default(TBenchTestResult);
  LRes.Name := 'probe';
  LRes.Executed := NextSegB(LRest) = 'T';
  LRes.Skipped := NextSegB(LRest) = 'T';
  LMetric := StrToIntDef(NextSegB(LRest), 0) / 10.0;
  LThr := StrToIntDef(NextSegB(LRest), 0) / 10.0;
  LMsgParam := NextSegB(LRest);
  if LMsgParam = '-' then
    LMsgParam := '';
  LWant := NextSegB(LRest);
  LFlag := LRest;

  if LKind = 'p' then
    LRes.NsPerOp := LMetric
  else
    LRes.OpsPerSec := LMetric;

  LRaised := False;
  LGotMsg := '';
  try
    if LKind = 'p' then
      CheckBenchPerformance(LRes, LThr, LMsgParam)
    else
      CheckBenchThroughput(LRes, LThr, LMsgParam);
  except
    on E: EAssertionFailed do
    begin
      LRaised := True;
      LGotMsg := E.Message;
    end;
  end;

  if LWant = 'pass' then
    CheckFalse(LRaised, AC.Name + ': no assertion expected')
  else
  begin
    CheckTrue(LRaised, AC.Name + ': assertion expected');
    CheckEqual(LWant, LGotMsg, AC.Name + ': message exact');
  end;

  { flag 自校验：'0' ⟺ 失败行 }
  if LFlag = '0' then
    CheckTrue(LWant <> 'pass', AC.Name + ': flag-0 must be fail row')
  else
    CheckEqual('pass', LWant, AC.Name + ': flag-1 must be pass row');
end;

{ Data: probe|want|flag — probe 选择探测点，want exact。
  suite/runtest 行用快速配置（MinDurationMs=1/MinSamples=1/MaxIterations=1）
  跑真实 bench 引擎，锁定条目保序与 Name 传播。 }
procedure RunBenchStructCase(const AC: TTestCase);
var
  LRest, LProbe, LWant, LFlag, LGot: string;
  LCfg, LFast: TBenchTestConfig;
  LEntries: array[0..1] of TBenchTestEntry;
  LEmpty: array of TBenchTestEntry;
  LArr: TBenchTestResultArray;
  LRes: TBenchTestResult;
begin
  LRest := AC.Data;
  LProbe := NextSegB(LRest);
  LWant := NextSegB(LRest);
  LFlag := LRest;
  LGot := '<unset>';

  LFast := DefaultBenchTestConfig;
  LFast.MinDurationMs := 1;
  LFast.MinSamples := 1;
  LFast.MaxIterations := 1;

  LCfg := DefaultBenchTestConfig;
  if LProbe = 'cfg-mindur' then
    LGot := IntToStr(LCfg.MinDurationMs)
  else if LProbe = 'cfg-minsamples' then
    LGot := IntToStr(LCfg.MinSamples)
  else if LProbe = 'cfg-maxiter' then
    LGot := IntToStr(LCfg.MaxIterations)
  else if LProbe = 'cfg-timeout' then
    LGot := IntToStr(LCfg.TimeoutMs)
  else if LProbe = 'cfg-threads' then
    LGot := IntToStr(LCfg.ThreadCount)
  else if (LProbe = 'suite-empty-len') or (LProbe = 'suite-empty-nil') then
  begin
    SetLength(LEmpty, 0);
    LArr := RunBenchSuite('v838-empty', LEmpty, LFast);
    if LProbe = 'suite-empty-len' then
      LGot := IntToStr(Length(LArr))
    else if LArr = nil then
      LGot := 'nil'
    else
      LGot := 'non-nil';
  end
  else if Pos('suite-two-', LProbe) = 1 then
  begin
    LEntries[0].Name := 'alpha';
    LEntries[0].Func := @BenchNoop;
    LEntries[1].Name := 'beta';
    LEntries[1].Func := @BenchIncrement;
    LArr := RunBenchSuite('v838-duo', LEntries, LFast);
    if LProbe = 'suite-two-count' then
      LGot := IntToStr(Length(LArr))
    else if Length(LArr) = 2 then
    begin
      if LProbe = 'suite-two-name0' then
        LGot := LArr[0].Name
      else if LProbe = 'suite-two-name1' then
        LGot := LArr[1].Name
      else if LProbe = 'suite-two-exec' then
        LGot := BoolMark(LArr[0].Executed) + BoolMark(LArr[1].Executed);
    end;
  end
  else if Pos('runtest-', LProbe) = 1 then
  begin
    LRes := RunBenchTest('gamma', @BenchNoop, LFast);
    if LProbe = 'runtest-name' then
      LGot := LRes.Name
    else if LProbe = 'runtest-flags' then
      LGot := BoolMark(LRes.Executed) + BoolMark(LRes.Skipped);
  end;

  CheckEqual(LWant, LGot, AC.Name + ': probe exact');

  { flag 自校验：'0' ⟺ 空/零值输出行 }
  if LFlag = '0' then
    CheckTrue((LWant = '0') or (LWant = 'nil'),
      AC.Name + ': flag-0 must be empty/zero row')
  else
    CheckTrue((LWant <> '0') and (LWant <> 'nil'),
      AC.Name + ': flag-1 must be non-empty row');
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  S: TTestSuite;
  LFpCases: specialize TArray<TTestCase>;
  LFpI: Integer;
  LChkCases: specialize TArray<TTestCase>;
  LStCases: specialize TArray<TTestCase>;
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

  { v8.38: CheckBench* 判定矩阵（合成记录，零计时依赖） }
  SetLength(LChkCases, 0);
  AppendBCase(LChkCases, 'b-p-below',          'p|T|F|15|20|-|pass', '1');
  AppendBCase(LChkCases, 'b-p-equal',          'p|T|F|20|20|-|pass', '1');
  AppendBCase(LChkCases, 'b-p-above',          'p|T|F|25|20|-|Benchmark "probe" performance 2.5 ns/op exceeds threshold 2.0 ns/op', '0');
  AppendBCase(LChkCases, 'b-p-notexec',        'p|F|F|10|20|-|Benchmark "probe" performance 1.0 ns/op exceeds threshold 2.0 ns/op', '0');
  AppendBCase(LChkCases, 'b-p-skip-pass',      'p|T|T|10|20|-|pass', '1');
  AppendBCase(LChkCases, 'b-p-skip-fail',      'p|F|T|10|20|-|Benchmark "probe" performance 1.0 ns/op exceeds threshold 2.0 ns/op', '0');
  AppendBCase(LChkCases, 'b-p-custom',         'p|T|F|30|20|slow!|slow!', '0');
  AppendBCase(LChkCases, 'b-p-custom-idle',    'p|T|F|10|20|unused|pass', '1');
  AppendBCase(LChkCases, 'b-p-neg-thr',        'p|T|F|0|-10|-|Benchmark "probe" performance 0.0 ns/op exceeds threshold -1.0 ns/op', '0');
  AppendBCase(LChkCases, 'b-p-zero-zero',      'p|T|F|0|0|-|pass', '1');
  AppendBCase(LChkCases, 'b-p-big',            'p|T|F|10000|9999|-|Benchmark "probe" performance 1000.0 ns/op exceeds threshold 999.9 ns/op', '0');
  AppendBCase(LChkCases, 'b-p-notexec-custom', 'p|F|F|10|20|why|why', '0');
  AppendBCase(LChkCases, 'b-t-above',          't|T|F|1000|500|-|pass', '1');
  AppendBCase(LChkCases, 'b-t-equal',          't|T|F|500|500|-|pass', '1');
  AppendBCase(LChkCases, 'b-t-below',          't|T|F|250|500|-|Benchmark "probe" throughput 25 ops/s below threshold 50 ops/s', '0');
  AppendBCase(LChkCases, 'b-t-notexec',        't|F|F|1000|500|-|Benchmark "probe" throughput 100 ops/s below threshold 50 ops/s', '0');
  AppendBCase(LChkCases, 'b-t-skip-pass',      't|T|T|1000|500|-|pass', '1');
  AppendBCase(LChkCases, 'b-t-skip-fail',      't|F|T|1000|500|-|Benchmark "probe" throughput 100 ops/s below threshold 50 ops/s', '0');
  AppendBCase(LChkCases, 'b-t-custom',         't|T|F|100|500|slow throughput|slow throughput', '0');
  AppendBCase(LChkCases, 'b-t-zero-thr',       't|T|F|10|0|-|pass', '1');
  AppendBCase(LChkCases, 'b-t-round-half',     't|T|F|495|500|-|Benchmark "probe" throughput 50 ops/s below threshold 50 ops/s', '0');
  AppendBCase(LChkCases, 'b-t-neg-metric',     't|T|F|-10|0|-|Benchmark "probe" throughput -1 ops/s below threshold 0 ops/s', '0');
  S.TestTable('v8.38 CheckBench decision matrix', LChkCases, @RunBenchCheckCase);

  { v8.38: config 默认值 + suite/runtest 结构契约 }
  SetLength(LStCases, 0);
  AppendBCase(LStCases, 'st-cfg-mindur',      'cfg-mindur|100', '1');
  AppendBCase(LStCases, 'st-cfg-minsamples',  'cfg-minsamples|5', '1');
  AppendBCase(LStCases, 'st-cfg-maxiter',     'cfg-maxiter|0', '0');
  AppendBCase(LStCases, 'st-cfg-timeout',     'cfg-timeout|5000', '1');
  AppendBCase(LStCases, 'st-cfg-threads',     'cfg-threads|1', '1');
  AppendBCase(LStCases, 'st-suite-empty-len', 'suite-empty-len|0', '0');
  AppendBCase(LStCases, 'st-suite-empty-nil', 'suite-empty-nil|nil', '0');
  AppendBCase(LStCases, 'st-suite-two-count', 'suite-two-count|2', '1');
  AppendBCase(LStCases, 'st-suite-two-name0', 'suite-two-name0|alpha', '1');
  AppendBCase(LStCases, 'st-suite-two-name1', 'suite-two-name1|beta', '1');
  AppendBCase(LStCases, 'st-suite-two-exec',  'suite-two-exec|TT', '1');
  AppendBCase(LStCases, 'st-runtest-name',    'runtest-name|gamma', '1');
  AppendBCase(LStCases, 'st-runtest-flags',   'runtest-flags|TF', '1');
  S.TestTable('v8.38 bench structure contract', LStCases, @RunBenchStructCase);

  S.Run;
  S.Summary;
  if not S.AllPassed then
    Halt(1);
end.
