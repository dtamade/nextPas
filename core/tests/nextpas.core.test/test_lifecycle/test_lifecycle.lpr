{ test_lifecycle.lpr — nextpas.core.test lifecycle, closure, table, facade
  =========================================================
  Covers: TestTable, TTestClosure (setup/teardown/beforeEach/afterEach),
          ITestContext.Fail, ITestContext.Skip, TTestRunner.AllPassed auto-run,
          closure-based Test() overloads, TTestSuite.Create defaults }

program test_lifecycle;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  cthreads,
  SysUtils,
  nextpas.core.test.base,
  nextpas.core.test.check,
  nextpas.core.test.expect,
  nextpas.core.test.runner,
  nextpas.core.test.runner.context;

var
  GTestsRun: Integer = 0;
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
  Inc(GTestsRun);
  if ACase.Name = 'add' then
    CheckEqual(StrToInt(ACase.Data), 1 + 1)
  else if ACase.Name = 'mul' then
    CheckEqual(StrToInt(ACase.Data), 2 * 3)
  else
    Fail('Unknown case: ' + ACase.Name);
end;

procedure TestTableStringProc(const ACase: TTestCase);
begin
  Inc(GTestsRun);
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
  Runner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
  LC1, LC2: TTestClosure;
begin
  Inc(GTestsRun);
  Suite := TTestSuite.Create('closure-basic');
  LC1 := @ClosurePass;
  LC2 := @ClosureExpect;
  Suite.Test('closure-pass', LC1);
  Suite.Test('closure-expect', LC2);
  Runner := TTestRunner.Create('closure-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  CheckTrue(LSuccess, 'Closure tests should pass');
  CheckTrue(Runner.TotalPass = 2, 'Expected 2 closures passed');
end;

procedure TestClosureSetupTeardown;
var
  Suite: TTestSuite;
  Runner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
  LSetup, LTear, LC1, LC2: TTestClosure;
begin
  Inc(GTestsRun);
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
  Runner := TTestRunner.Create('closure-lifecycle-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  CheckTrue(LSuccess, 'Closure lifecycle should pass');
  CheckEqual(GSetupCalls, 1);
  CheckEqual(GTeardownCalls, 1);
  CheckEqual(Runner.TotalPass, 2);
end;

procedure TestClosureBeforeEachAfterEach;
var
  Suite: TTestSuite;
  Runner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
  LBefore, LAfter, LC: TTestClosure;
begin
  Inc(GTestsRun);
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
  Runner := TTestRunner.Create('closure-hooks-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  CheckTrue(LSuccess, 'Closure hooks should pass');
  CheckEqual(GBeforeEachCalls, 3);
  CheckEqual(GAfterEachCalls, 3);
end;

procedure SimpleTrue;
begin
  CheckTrue(True);
end;

{ ── ITestContext.Fail ──────────────────────────────────────────────────────── }

procedure CtxFailProc;
begin
  InternalFail('deliberate failure from ITestContext');
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
  Inc(GTestsRun);
  Suite := TTestSuite.Create('ctx-fail');
  Suite.TestSubtest('fail-via-ctx', @CtxFailSubtest);
  Suite.RunWithResult(LResult);
  CheckTrue(LResult.Failed >= 1, 'Ctx.Fail should propagate as failure');
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
  Inc(GTestsRun);
  Suite := TTestSuite.Create('ctx-skip');
  Suite.TestSubtest('skip-via-ctx', @CtxSkipSubtest);
  Suite.RunWithResult(LResult);
  { Subtest-level skips don't propagate to parent suite's skip count,
    but should not cause failures either }
  CheckTrue(LResult.Failed = 0, 'Skip in subtest should not cause failure');
  CheckTrue(LResult.AllPassed, 'Suite should pass when subtests only skip');
end;

{ ── TTestRunner.AllPassed auto-run ─────────────────────────────────────────── }

procedure TestRunnerAllPassedAutoRun;
var
  Suite: TTestSuite;
  Runner: TTestRunner;
  LAutoPassed: Boolean;
begin
  Inc(GTestsRun);
  Suite := TTestSuite.Create('auto-run');
  Suite.Test('ok', @SimpleTrue);
  Runner := TTestRunner.Create('auto-runner');
  Runner.Add(Suite);
  CheckFalse(Runner.HasRun, 'HasRun should be false before AllPassed');
  LAutoPassed := Runner.AllPassed;
  CheckTrue(Runner.HasRun, 'HasRun should be true after AllPassed');
  CheckTrue(LAutoPassed, 'AllPassed should return true');
  CheckTrue(Runner.TotalPass = 1, 'Should have 1 pass after auto-run');
end;

{ ── TTestSuite.Create defaults ─────────────────────────────────────────────── }

procedure TestSuiteCreateDefaults;
var
  Suite: TTestSuite;
begin
  Inc(GTestsRun);
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
end;

{ ── TTestRunner.Create defaults ────────────────────────────────────────────── }

procedure TestRunnerCreateDefaults;
var
  Runner: TTestRunner;
begin
  Inc(GTestsRun);
  Runner := TTestRunner.Create('my-runner');
  CheckTrue(Runner.Name = 'my-runner');
  CheckTrue(Length(Runner.Suites) = 0);
  CheckTrue(Runner.TotalPass = 0);
  CheckTrue(Runner.TotalFail = 0);
  CheckTrue(Runner.TotalSkip = 0);
  CheckFalse(Runner.HasRun);
end;

{ ── TTestSuite.Skip ────────────────────────────────────────────────────────── }

procedure TestSuiteSkip;
var
  Suite: TTestSuite;
  LResult: TTestRunResult;
begin
  Inc(GTestsRun);
  Suite := TTestSuite.Create('skip-suite');
  Suite.Skip('skipped_a', 'not implemented');
  Suite.Skip('skipped_b');
  Suite.Test('pass', @SimpleTrue);
  Suite.RunWithResult(LResult);
  CheckTrue(LResult.Skipped = 2, 'Should have 2 skipped');
  CheckTrue(LResult.Passed = 1, 'Should have 1 pass');
  CheckTrue(LResult.AllPassed, 'AllPassed should be true');
end;

{ ── TestTable integration ──────────────────────────────────────────────────── }

procedure TestTableSerial;
var
  Suite: TTestSuite;
  LResult: TTestRunResult;
  LMathCases, LStrCases: specialize TArray<TTestCase>;
begin
  Inc(GTestsRun);
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
end;

procedure TestTableParallel;
var
  Suite: TTestSuite;
  LResult: TTestRunResult;
  LSuccess: Boolean;
  LMathCases: specialize TArray<TTestCase>;
begin
  Inc(GTestsRun);
  Suite := TTestSuite.Create('table-parallel');
  SetLength(LMathCases, 2);
  LMathCases[0] := MakeCase('add', '2');
  LMathCases[1] := MakeCase('mul', '6');
  Suite.TestTable('math', LMathCases, @TestTableBasicProc);
  LSuccess := Suite.RunParallelWithResult(nil, LResult);
  CheckTrue(LSuccess, 'Parallel table should pass');
  CheckTrue(LResult.Passed = 2, 'Expected 2 parallel table passes');
end;

{ ── Closure + Parallel integration ─────────────────────────────────────────── }

procedure TestClosureParallel;
var
  Suite: TTestSuite;
  LResult: TTestRunResult;
  LSuccess: Boolean;
  LC1, LC2, LC3: TTestClosure;
begin
  Inc(GTestsRun);
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
end;

{ ── R6-57: Setup failure → Teardown not called ────────────────────────────── }

var
  GSetupFailTeardownCalled: Integer = 0;

procedure R657SetupFailTeardown;
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  Inc(GTestsRun);
  GSetupFailTeardownCalled := 0;
  LSuite := TTestSuite.Create('setup-fail-teardown');
  LSuite.SetSetup(procedure begin raise EConvertError.Create('setup boom'); end);
  LSuite.SetTeardown(procedure begin Inc(GSetupFailTeardownCalled); end);
  LSuite.Test('after bad setup', @SimpleTrue);
  LSuite.RunWithResult(LResult);
  { When Setup fails, Teardown should NOT run (no teardown for partial init) }
  CheckEqual(GSetupFailTeardownCalled, 0);
  CheckTrue(LResult.Failed >= 1, 'Setup failure should count as failure');
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
  Inc(GTestsRun);
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
  Inc(GTestsRun);
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

{ ── Main ───────────────────────────────────────────────────────────────────── }

var
  Suite: TTestSuite;
  Runner: TTestRunner;
  LResults: specialize TArray<TTestRunResult>;
  LSuccess: Boolean;
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

  Runner := TTestRunner.Create('lifecycle-tests');
  Runner.Add(Suite);
  LSuccess := Runner.RunAllWithResult(LResults);
  WriteLn;
  Runner.Summary;

  CheckTrue(GTestsRun >= 15, 'Expected at least 15 tests, got ' + IntToStr(GTestsRun));
  CheckTrue(LSuccess, 'All lifecycle tests should pass');

  if Runner.AllPassed then
    WriteLn('ALL PASSED')
  else
  begin
    WriteLn('SOME FAILED');
    Halt(1);
  end;
end.
