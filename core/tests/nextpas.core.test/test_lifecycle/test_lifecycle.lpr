{ test_lifecycle — Lifecycle, closure, table, facade coverage
  =========================================================
  Covers: TestTable, TTestClosure (setup/teardown/beforeEach/afterEach),
          ITestContext.Fail, ITestContext.Skip, TSuiteRunner.AllPassed auto-run,
          closure-based Test() overloads, TTestSuite.Create defaults }

program test_lifecycle;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  { 白盒测试：直接覆盖 runner.context 的结果收集边界。 }
  nextpas.core.test.runner.context;

var
  GSetupCalls: Integer = 0;
  GTeardownCalls: Integer = 0;
  GBeforeEachCalls: Integer = 0;
  GAfterEachCalls: Integer = 0;

{ ── Helper to build test cases ─────────────────────────────────────────────── }

function MakeCase(const AName, AData: string): TTestCase;
begin
  Result.Name := AName;
  Result.Data := AData;
end;

{ ── TestTable (parameterized tests) ────────────────────────────────────────── }

procedure TestTableBasicProc(const ACase: TTestCase);
begin
  if ACase.Name = 'add' then
    CheckEqual(StrToInt(ACase.Data), 1 + 1)
  else if ACase.Name = 'mul' then
    CheckEqual(StrToInt(ACase.Data), 2 * 3)
  else
    Fail('Unknown case: ' + ACase.Name);
end;

procedure TestTableStringProc(const ACase: TTestCase);
begin
  if ACase.Name = 'upper' then
    CheckEqual(ACase.Data, 'HELLO')
  else if ACase.Name = 'lower' then
    CheckEqual(ACase.Data, 'hello')
  else if ACase.Name = 'empty' then
    CheckEqual(ACase.Data, '')
  else
    Fail('Unknown case: ' + ACase.Name);
end;

{ ── Named closure procedures (for TTestClosure tests) ──────────────────────── }

procedure ClosurePass;
begin
  CheckTrue(True);
end;

procedure ClosureExpect;
begin
  Expect('hello').ToEqual('hello');
end;

procedure ClosureSetupProc;
begin
  Inc(GSetupCalls);
end;

procedure ClosureTeardownProc;
begin
  Inc(GTeardownCalls);
end;

procedure ClosureBeforeEachProc;
begin
  Inc(GBeforeEachCalls);
end;

procedure ClosureAfterEachProc;
begin
  Inc(GAfterEachCalls);
end;

procedure ClosureCheckInt;
begin
  CheckEqual(2 + 2, 4);
end;

procedure ClosureExpectX;
begin
  Expect('x').ToEqual('x');
end;

{ ── Closure-based tests ────────────────────────────────────────────────────── }

procedure TestClosureBasic;
var
  Suite: TTestSuite;
  Runner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
  LC1, LC2: TTestClosure;
begin
  Suite := TTestSuite.Create('closure-basic');
  LC1 := @ClosurePass;
  LC2 := @ClosureExpect;
  Suite.Test('closure-pass', LC1);
  Suite.Test('closure-expect', LC2);
  Runner := TSuiteRunner.Create('closure-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  CheckTrue(LSuccess, 'Closure tests should pass');
  CheckTrue(Runner.TotalPass = 2, 'Expected 2 closures passed');
  Runner := Default(TSuiteRunner);
  Suite := Default(TTestSuite);
end;

procedure TestClosureSetupTeardown;
var
  Suite: TTestSuite;
  Runner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
  LSetup, LTear, LC1, LC2: TTestClosure;
begin
  GSetupCalls := 0;
  GTeardownCalls := 0;
  Suite := TTestSuite.Create('closure-lifecycle');
  LSetup := @ClosureSetupProc;
  LTear := @ClosureTeardownProc;
  Suite.SetSetup(LSetup);
  Suite.SetTeardown(LTear);
  LC1 := @ClosurePass;
  LC2 := @ClosurePass;
  Suite.Test('t1', LC1);
  Suite.Test('t2', LC2);
  Runner := TSuiteRunner.Create('closure-lifecycle-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  CheckTrue(LSuccess, 'Closure lifecycle should pass');
  CheckEqual(GSetupCalls, 1);
  CheckEqual(GTeardownCalls, 1);
  CheckEqual(Runner.TotalPass, 2);
  Runner := Default(TSuiteRunner);
  Suite := Default(TTestSuite);
end;

procedure TestClosureBeforeEachAfterEach;
var
  Suite: TTestSuite;
  Runner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
  LBefore, LAfter, LC: TTestClosure;
begin
  GBeforeEachCalls := 0;
  GAfterEachCalls := 0;
  Suite := TTestSuite.Create('closure-hooks');
  LBefore := @ClosureBeforeEachProc;
  LAfter := @ClosureAfterEachProc;
  Suite.OnBeforeEach(LBefore);
  Suite.OnAfterEach(LAfter);
  LC := @ClosurePass;
  Suite.Test('h1', LC);
  Suite.Test('h2', LC);
  Suite.Test('h3', LC);
  Runner := TSuiteRunner.Create('closure-hooks-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  CheckTrue(LSuccess, 'Closure hooks should pass');
  CheckEqual(GBeforeEachCalls, 3);
  CheckEqual(GAfterEachCalls, 3);
  Runner := Default(TSuiteRunner);
  Suite := Default(TTestSuite);
end;

procedure SimpleTrue;
begin
  CheckTrue(True);
end;

{ ── ITestContext.Fail ──────────────────────────────────────────────────────── }

procedure CtxFailProc;
begin
  Fail('deliberate failure from ITestContext');
end;

procedure CtxFailSubtest(constref Ctx: ITestContext);
begin
  Ctx.Run('will-fail', @CtxFailProc);
end;

procedure TestITestContextFail;
var
  Suite: TTestSuite;
  LResult: TTestRunResult;
begin
  Suite := TTestSuite.Create('ctx-fail');
  Suite.TestSubtest('fail-via-ctx', @CtxFailSubtest);
  Suite.RunWithResult(LResult);
  CheckTrue(LResult.Failed >= 1, 'Ctx.Fail should propagate as failure');
  Suite := Default(TTestSuite);
end;

{ ── ITestContext.Skip ──────────────────────────────────────────────────────── }

procedure CtxSkipProc;
begin
  Skip('deliberately skipped via ITestContext');
end;

procedure CtxSkipSubtest(constref Ctx: ITestContext);
begin
  Ctx.Run('will-skip', @CtxSkipProc);
  Ctx.Run('will-pass', @SimpleTrue);
end;

procedure TestITestContextSkip;
var
  Suite: TTestSuite;
  LResult: TTestRunResult;
begin
  Suite := TTestSuite.Create('ctx-skip');
  Suite.TestSubtest('skip-via-ctx', @CtxSkipSubtest);
  Suite.RunWithResult(LResult);
  { Subtest-level skips don't propagate to parent suite's skip count,
    but should not cause failures either }
  CheckTrue(LResult.Failed = 0, 'Skip in subtest should not cause failure');
  CheckTrue(LResult.AllPassed, 'Suite should pass when subtests only skip');
  Suite := Default(TTestSuite);
end;

{ ── TSuiteRunner.AllPassed auto-run ─────────────────────────────────────────── }

procedure TestRunnerAllPassedAutoRun;
var
  Suite: TTestSuite;
  Runner: TSuiteRunner;
  LAutoPassed: Boolean;
begin
  Suite := TTestSuite.Create('auto-run');
  Suite.Test('ok', @SimpleTrue);
  Runner := TSuiteRunner.Create('auto-runner');
  Runner.Add(Suite);
  CheckFalse(Runner.HasRun, 'HasRun should be false before AllPassed');
  LAutoPassed := Runner.AllPassed;
  CheckTrue(Runner.HasRun, 'HasRun should be true after AllPassed');
  CheckTrue(LAutoPassed, 'AllPassed should return true');
  CheckTrue(Runner.TotalPass = 1, 'Should have 1 pass after auto-run');
  Runner := Default(TSuiteRunner);
  Suite := Default(TTestSuite);
end;

{ ── TTestSuite.Create defaults ─────────────────────────────────────────────── }

procedure TestSuiteCreateDefaults;
var
  Suite: TTestSuite;
begin
  Suite := TTestSuite.Create('defaults');
  CheckTrue(Suite.Name = 'defaults');
  CheckTrue(Length(Suite.Tests) = 0);
  CheckTrue(Suite.Setup = nil);
  CheckTrue(Suite.SetupClosure = nil);
  CheckTrue(Suite.Teardown = nil);
  CheckTrue(Suite.TeardownClosure = nil);
  CheckTrue(Suite.BeforeEach = nil);
  CheckTrue(Suite.BeforeEachClosure = nil);
  CheckTrue(Suite.AfterEach = nil);
  CheckTrue(Suite.AfterEachClosure = nil);
  CheckFalse(Suite.LastRunPassed);
  CheckFalse(Suite.HasRun);
  CheckTrue(Suite.LastPass = 0);
  CheckTrue(Suite.LastFail = 0);
  CheckTrue(Suite.LastSkip = 0);
  Suite := Default(TTestSuite);
end;

{ ── TSuiteRunner.Create defaults ────────────────────────────────────────────── }

procedure TestRunnerCreateDefaults;
var
  Runner: TSuiteRunner;
begin
  Runner := TSuiteRunner.Create('my-runner');
  CheckTrue(Runner.Name = 'my-runner');
  CheckTrue(Length(Runner.Suites) = 0);
  CheckTrue(Runner.TotalPass = 0);
  CheckTrue(Runner.TotalFail = 0);
  CheckTrue(Runner.TotalSkip = 0);
  CheckFalse(Runner.HasRun);
  Runner := Default(TSuiteRunner);
end;

{ ── TTestSuite.Skip ────────────────────────────────────────────────────────── }

procedure TestSuiteSkip;
var
  Suite: TTestSuite;
  LResult: TTestRunResult;
begin
  Suite := TTestSuite.Create('skip-suite');
  Suite.Skip('skipped_a', 'not implemented');
  Suite.Skip('skipped_b');
  Suite.Test('pass', @SimpleTrue);
  Suite.RunWithResult(LResult);
  CheckTrue(LResult.Skipped = 2, 'Should have 2 skipped');
  CheckTrue(LResult.Passed = 1, 'Should have 1 pass');
  CheckTrue(LResult.AllPassed, 'AllPassed should be true');
  Suite := Default(TTestSuite);
end;

{ ── TestTable integration ──────────────────────────────────────────────────── }

procedure TestTableSerial;
var
  Suite: TTestSuite;
  LResult: TTestRunResult;
  LMathCases, LStrCases: specialize TArray<TTestCase>;
begin
  Suite := TTestSuite.Create('table-serial');
  SetLength(LMathCases, 2);
  LMathCases[0] := MakeCase('add', '2');
  LMathCases[1] := MakeCase('mul', '6');
  Suite.TestTable('math', LMathCases, @TestTableBasicProc);

  SetLength(LStrCases, 3);
  LStrCases[0] := MakeCase('upper', 'HELLO');
  LStrCases[1] := MakeCase('lower', 'hello');
  LStrCases[2] := MakeCase('empty', '');
  Suite.TestTable('strings', LStrCases, @TestTableStringProc);

  Suite.RunWithResult(LResult);
  CheckTrue(LResult.Passed = 5, 'Expected 5 table tests');
  CheckTrue(LResult.AllPassed, 'All table tests should pass');
  Suite := Default(TTestSuite);
end;

procedure TestTableParallel;
var
  Suite: TTestSuite;
  LResult: TTestRunResult;
  LSuccess: Boolean;
  LMathCases: specialize TArray<TTestCase>;
begin
  Suite := TTestSuite.Create('table-parallel');
  SetLength(LMathCases, 2);
  LMathCases[0] := MakeCase('add', '2');
  LMathCases[1] := MakeCase('mul', '6');
  Suite.TestTable('math', LMathCases, @TestTableBasicProc);
  LSuccess := Suite.RunParallelWithResult(nil, LResult);
  CheckTrue(LSuccess, 'Parallel table should pass');
  CheckTrue(LResult.Passed = 2, 'Expected 2 parallel table passes');
  Suite := Default(TTestSuite);
end;

{ ── Closure + Parallel integration ─────────────────────────────────────────── }

procedure TestClosureParallel;
var
  Suite: TTestSuite;
  LResult: TTestRunResult;
  LSuccess: Boolean;
  LC1, LC2, LC3: TTestClosure;
begin
  Suite := TTestSuite.Create('closure-parallel');
  LC1 := @ClosurePass;
  LC2 := @ClosureCheckInt;
  LC3 := @ClosureExpectX;
  Suite.Test('cp1', LC1);
  Suite.Test('cp2', LC2);
  Suite.Test('cp3', LC3);
  LSuccess := Suite.RunParallelWithResult(nil, LResult);
  CheckTrue(LSuccess, 'Closure parallel should pass');
  CheckTrue(LResult.Passed = 3, 'Expected 3 parallel closures');
  Suite := Default(TTestSuite);
end;

{ ── R6-57: Setup failure → Teardown not called ────────────────────────────── }

var
  GSetupFailTeardownCalled: Integer = 0;
  GSetupFailBodyCalled: Integer = 0;
  GTeardownBoomSurvived: Integer = 0;
  GBeforeEachBoomBody: Integer = 0;
  GBeforeEachBoomAfter: Integer = 0;

procedure SimpleTrueIncBody;
begin
  Inc(GSetupFailBodyCalled);
  CheckTrue(True);
end;

procedure R657SetupFailTeardown;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  GSetupFailTeardownCalled := 0;
  LSuite := TTestSuite.Create('setup-fail-teardown');
  LSuite.SetSetup(procedure begin raise EConvertError.Create('setup boom'); end);
  LSuite.SetTeardown(procedure begin Inc(GSetupFailTeardownCalled); end);
  LSuite.Test('after bad setup', @SimpleTrue);
  LSuite.RunWithResult(LResult);
  { When Setup fails, Teardown should NOT run (no teardown for partial init) }
  CheckEqual(GSetupFailTeardownCalled, 0);
  CheckTrue(LResult.Failed >= 1, 'Setup failure should count as failure');
  LSuite := Default(TTestSuite);
end;

{ ── B10: Setup failure deep contract ──────────────────────────────────────── }

procedure B10SetupFailBodyNotRun;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LFoundSetupError: Boolean;
  LFoundSkipped: Boolean;
begin
  GSetupFailBodyCalled := 0;
  GSetupFailTeardownCalled := 0;
  LSuite := TTestSuite.Create('setup-fail-body');
  LSuite.SetSetup(procedure begin raise EConvertError.Create('setup boom'); end);
  LSuite.SetTeardown(procedure begin Inc(GSetupFailTeardownCalled); end);
  LSuite.Test('body-a', @SimpleTrueIncBody);
  LSuite.Test('body-b', @SimpleTrueIncBody);
  LSuite.RunWithResult(LResult);
  CheckEqual(GSetupFailBodyCalled, 0, 'body must not run after setup fail');
  CheckEqual(GSetupFailTeardownCalled, 0, 'teardown must not run after setup fail');
  LFoundSetupError := False;
  LFoundSkipped := False;
  for I := 0 to High(LResult.Results) do
  begin
    if (LResult.Results[I].Name = '[setup]') and
       (LResult.Results[I].Status = tsError) then
      LFoundSetupError := True;
    if (LResult.Results[I].Status = tsSkipped) and
       (Pos('setup failed', LResult.Results[I].Message) > 0) then
      LFoundSkipped := True;
  end;
  CheckTrue(LFoundSetupError, 'expect synthetic [setup] tsError');
  CheckTrue(LFoundSkipped, 'expect per-test tsSkipped with setup failed');
  LSuite := Default(TTestSuite);
end;

procedure B10SetupSkipViaETestSkipped;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LOk: Boolean;
  I: Integer;
  LFoundSkipped: Boolean;
begin
  { R4-01: setup ETestSkipped skips all tests but suite Result=False
    (synthetic [setup] path). Body must never run. }
  GSetupFailBodyCalled := 0;
  LSuite := TTestSuite.Create('setup-skip');
  LSuite.SetSetup(procedure
    begin
      raise ETestSkipped.Create('setup short-circuit');
    end);
  LSuite.Test('should-skip', @SimpleTrueIncBody);
  LOk := LSuite.RunWithResult(LResult);
  CheckEqual(GSetupFailBodyCalled, 0, 'body not run on setup skip');
  CheckFalse(LOk, 'R4-01: setup skip makes suite not AllPassed');
  LFoundSkipped := False;
  for I := 0 to High(LResult.Results) do
    if LResult.Results[I].Status = tsSkipped then
      LFoundSkipped := True;
  CheckTrue(LFoundSkipped, 'tests recorded as skipped after setup skip');
  LSuite := Default(TTestSuite);
end;

procedure B10TeardownExceptionSwallowed;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  LOk: Boolean;
begin
  GTeardownBoomSurvived := 0;
  LSuite := TTestSuite.Create('teardown-boom');
  LSuite.SetTeardown(procedure
    begin
      raise EConvertError.Create('teardown boom');
    end);
  LSuite.Test('still-pass', procedure
    begin
      Inc(GTeardownBoomSurvived);
      CheckTrue(True);
    end);
  LOk := LSuite.RunWithResult(LResult);
  CheckEqual(GTeardownBoomSurvived, 1, 'test body ran');
  CheckTrue(LOk, 'teardown exception must not fail the suite');
  CheckTrue(LResult.Passed >= 1, 'test still passed');
  CheckTrue(LResult.Failed = 0, 'no failure from teardown');
  LSuite := Default(TTestSuite);
end;

procedure B10BeforeEachFailSkipsBodyRunsAfterEach;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LFoundBeforeEach: Boolean;
begin
  GBeforeEachBoomBody := 0;
  GBeforeEachBoomAfter := 0;
  LSuite := TTestSuite.Create('beforeeach-boom');
  LSuite.OnBeforeEach(procedure
    begin
      raise EConvertError.Create('beforeEach boom');
    end);
  LSuite.OnAfterEach(procedure
    begin
      Inc(GBeforeEachBoomAfter);
    end);
  LSuite.Test('body', procedure
    begin
      Inc(GBeforeEachBoomBody);
      CheckTrue(True);
    end);
  LSuite.RunWithResult(LResult);
  CheckEqual(GBeforeEachBoomBody, 0, 'body skipped when BeforeEach fails');
  CheckEqual(GBeforeEachBoomAfter, 1, 'AfterEach still runs after BeforeEach fail');
  LFoundBeforeEach := False;
  for I := 0 to High(LResult.Results) do
    if (LResult.Results[I].Status = tsError) and
       (Pos('beforeEach failed', LResult.Results[I].Message) > 0) then
      LFoundBeforeEach := True;
  CheckTrue(LFoundBeforeEach, 'result message mentions beforeEach failed');
  LSuite := Default(TTestSuite);
end;

{ ── B30: lifecycle fail-path table (AfterEach always runs) ────────────────── }

var
  GB30After: Integer;

procedure B30LifecycleFailPathCase(const AC: TTestCase);
{ Data: pass | soft | hard | soft2
  Assert: AfterEach runs once; suite pass/fail matches mode; soft join exact. }
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  GB30After := 0;
  LSuite := TTestSuite.Create('lc-fp-' + AC.Name);
  LSuite.OnAfterEach(procedure
    begin
      Inc(GB30After);
    end);
  if AC.Data = 'pass' then
    LSuite.Test('t', procedure
      begin
        CheckTrue(True);
      end)
  else if AC.Data = 'soft' then
    LSuite.Test('t', procedure
      begin
        SoftFail('lc soft ' + AC.Name);
      end)
  else if AC.Data = 'soft2' then
    LSuite.Test('t', procedure
      begin
        SoftFail('a-' + AC.Name);
        SoftFail('b-' + AC.Name);
      end)
  else { hard }
    LSuite.Test('t', procedure
      begin
        CheckTrue(False, 'lc hard ' + AC.Name);
      end);
  LSuite.RunWithResult(LResult);
  CheckEqual(1, GB30After, 'AfterEach once for ' + AC.Name);
  if AC.Data = 'pass' then
  begin
    CheckTrue(LResult.AllPassed, 'pass case ' + AC.Name);
    CheckEqual(1, LResult.Passed);
  end
  else
  begin
    CheckFalse(LResult.AllPassed, 'fail-path ' + AC.Name);
    CheckEqual(1, LResult.Failed);
    if AC.Data = 'soft' then
      CheckEqual('lc soft ' + AC.Name, LResult.Results[0].Message)
    else if AC.Data = 'soft2' then
      CheckEqual('a-' + AC.Name + '; b-' + AC.Name, LResult.Results[0].Message)
    else
      CheckEqual('lc hard ' + AC.Name, LResult.Results[0].Message);
  end;
  LSuite := Default(TTestSuite);
end;

{ ── Facade completeness ───────────────────────────────────────────────────── }

procedure TestFacadeSymbols;
var
  LStatus: TTestStatus;
  LResult: TTestResult;
  LRunResult: TTestRunResult;
  LProc: TTestProc;
  LClosure: TTestClosure;
  LSubProc: TSubtestProc;
  LCase: TTestCase;
  LResults: TTestResults;
  LExcept: ExceptClass;
begin
  LStatus := tsPassed;
  CheckTrue(LStatus = tsPassed);
  LResult.Name := 'test';
  LResult.Status := tsPassed;
  LResult.Message := '';
  CheckEqual(LResult.Name, 'test');
  LRunResult := TTestRunResult.Create('facade');
  CheckEqual(LRunResult.SuiteName, 'facade');
  CheckTrue(LRunResult.AllPassed);
  LProc := nil;
  CheckTrue(not Assigned(LProc));
  LClosure := nil;
  CheckTrue(not Assigned(LClosure));
  LSubProc := nil;
  CheckTrue(not Assigned(LSubProc));
  LCase.Name := 'case1';
  LCase.Data := 'data1';
  CheckEqual(LCase.Name, 'case1');
  LResults := nil;
  CheckTrue(Length(LResults) = 0);
  LExcept := EAssertionFailed;
  CheckTrue(LExcept <> nil);
  LExcept := ETestSkipped;
  CheckTrue(LExcept <> nil);
end;

procedure TestResultAppenderResultsProperty;
var
  LAppender: TTestResultAppender;
  LCollectedResult: TTestResult;
begin
  { 白盒测试：验证 runner.context 通过只读 Results property 暴露收集结果。 }
  LAppender := TTestResultAppender.Create;
  try
    LCollectedResult.Name := 'subtest';
    LCollectedResult.Status := tsPassed;
    LCollectedResult.Message := '';
    LCollectedResult.Duration := 7;
    LAppender.Append(LCollectedResult);
    CheckEqual(1, Length(LAppender.Results));
    CheckEqual('subtest', LAppender.Results[0].Name);
    CheckEqual(Ord(tsPassed), Ord(LAppender.Results[0].Status));
  finally
    LAppender.Free;
  end;
end;

{ E-04: TTestConfigBuilder }

procedure TestConfigBuilder;
var
  LConfig: TTestConfig;
begin
  LConfig := TTestConfigBuilder.Create
    .WithFilter('my-test')
    .WithTimeout(5000)
    .WithFailFast(True)
    .WithShuffle(-1)
    .WithVerbose(True)
    .WithMaxFailures(3)
    .WithBench(True)
    .WithBenchTime(2000)
    .Build;
  CheckEqual(LConfig.FilterPattern, 'my-test');
  CheckEqual(Int64(LConfig.TimeoutMs), Int64(5000));
  CheckTrue(LConfig.FailFast, 'FailFast');
  CheckEqual(LConfig.ShuffleSeed, -1);
  CheckTrue(LConfig.VerboseMode, 'VerboseMode');
  CheckEqual(LConfig.MaxFailures, 3);
  CheckTrue(LConfig.BenchEnabled, 'BenchEnabled');
  CheckEqual(LConfig.BenchTimeMs, 2000);
end;

procedure TestConfigBuilderDefaults;
var
  LConfig: TTestConfig;
begin
  { Builder with no modifications should produce default config }
  LConfig := TTestConfigBuilder.Create.Build;
  CheckEqual(LConfig.FilterPattern, '');
  CheckEqual(Int64(LConfig.TimeoutMs), Int64(0));
  CheckFalse(LConfig.FailFast, 'FailFast default');
  CheckEqual(LConfig.ShuffleSeed, 0);
  CheckFalse(LConfig.VerboseMode, 'VerboseMode default');
end;

{ ── Main ───────────────────────────────────────────────────────────────────── }

var
  Suite: TTestSuite;
  Runner: TSuiteRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
  LB30Cases: specialize TArray<TTestCase>;
  LB30I: Integer;
begin
  WriteLn('=== test_lifecycle ===');
  Suite := TTestSuite.Create('lifecycle');
  Suite.Test('TestTableSerial', @TestTableSerial);
  Suite.Test('TestTableParallel', @TestTableParallel);
  Suite.Test('TestClosureBasic', @TestClosureBasic);
  Suite.Test('TestClosureSetupTeardown', @TestClosureSetupTeardown);
  Suite.Test('TestClosureBeforeEachAfterEach', @TestClosureBeforeEachAfterEach);
  Suite.Test('TestITestContextFail', @TestITestContextFail);
  Suite.Test('TestITestContextSkip', @TestITestContextSkip);
  Suite.Test('TestRunnerAllPassedAutoRun', @TestRunnerAllPassedAutoRun);
  Suite.Test('TestSuiteCreateDefaults', @TestSuiteCreateDefaults);
  Suite.Test('TestRunnerCreateDefaults', @TestRunnerCreateDefaults);
  Suite.Test('TestSuiteSkip', @TestSuiteSkip);
  Suite.Test('TestClosureParallel', @TestClosureParallel);
  Suite.Test('TestFacadeSymbols', @TestFacadeSymbols);
  Suite.Test('TestResultAppenderResultsProperty', @TestResultAppenderResultsProperty);
  Suite.Test('R657SetupFailTeardown', @R657SetupFailTeardown);
  Suite.Test('B10SetupFailBodyNotRun', @B10SetupFailBodyNotRun);
  Suite.Test('B10SetupSkipViaETestSkipped', @B10SetupSkipViaETestSkipped);
  Suite.Test('B10TeardownExceptionSwallowed', @B10TeardownExceptionSwallowed);
  Suite.Test('B10BeforeEachFailSkipsBodyRunsAfterEach',
    @B10BeforeEachFailSkipsBodyRunsAfterEach);

  { E-04: TTestConfigBuilder }
  Suite.Test('ConfigBuilder', @TestConfigBuilder);
  Suite.Test('ConfigBuilderDefaults', @TestConfigBuilderDefaults);

  { B30: AfterEach + SoftFail/Hard fail-path table (60 cases) }
  SetLength(LB30Cases, 60);
  for LB30I := 0 to High(LB30Cases) do
  begin
    LB30Cases[LB30I].Name := 'lc' + IntToStr(LB30I);
    case LB30I mod 4 of
      0: LB30Cases[LB30I].Data := 'pass';
      1: LB30Cases[LB30I].Data := 'soft';
      2: LB30Cases[LB30I].Data := 'hard';
    else
      LB30Cases[LB30I].Data := 'soft2';
    end;
  end;
  Suite.TestTable('B30 lifecycle fail-path AfterEach', LB30Cases,
    @B30LifecycleFailPathCase);

  Runner := TSuiteRunner.Create('lifecycle-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  WriteLn;
  Runner.Summary;

  CheckTrue(LResults[0].Passed >= 19, 'Expected at least 19 tests, got ' + IntToStr(LResults[0].Passed));
  CheckTrue(LSuccess, 'All lifecycle tests should pass');

  if Runner.AllPassed then
    PassTest('ALL PASSED')
  else
    FailTest('SOME FAILED');

  { Release closures before heaptrc reports (unit finalization runs before
    main block locals are freed — closures would appear as unfreed). }
  Runner := Default(TSuiteRunner);
  Suite := Default(TTestSuite);
  LResults := nil;
end.
