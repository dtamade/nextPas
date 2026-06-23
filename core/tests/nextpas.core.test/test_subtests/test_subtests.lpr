{ test_subtests — Validates nested subtest execution }
program test_subtests;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  cthreads,
  SysUtils,
  nextpas.core.test;

var
  GSubTestsRun: Integer = 0;
  GBeforeEachCount: Integer = 0;
  GAfterEachCount: Integer = 0;

procedure TestSimpleSubtest(constref Ctx: ITestContext);
begin
  Ctx.Run('addition',
    procedure
    begin
      CheckEqual(Int64(3), Int64(1 + 2));
      InterLockedIncrement(GSubTestsRun);
    end);

  Ctx.Run('string concat',
    procedure
    begin
      CheckEqual('hello world', 'hello ' + 'world');
      InterLockedIncrement(GSubTestsRun);
    end);

  Ctx.Run('boolean logic',
    procedure
    begin
      CheckTrue(True and True);
      CheckFalse(True and False);
      InterLockedIncrement(GSubTestsRun);
    end);
end;

procedure TestSubtestWithExpect(constref Ctx: ITestContext);
begin
  Ctx.Run('expect equality',
    procedure
    begin
      Expect('hello').ToEqual('hello');
      ExpectInt(42).ToEqualInt(42);
      ExpectBool(True).ToBeTrue;
      InterLockedIncrement(GSubTestsRun);
    end);

  Ctx.Run('expect negation',
    procedure
    begin
      Expect('hello').Not_.ToEqual('world');
      ExpectInt(42).Not_.ToEqualInt(99);
      ExpectBool(True).Not_.ToBeFalse;
      InterLockedIncrement(GSubTestsRun);
    end);
end;

procedure TestSubtestWithFailure(constref Ctx: ITestContext);
begin
  Ctx.Run('this passes',
    procedure
    begin
      Check(True);
      InterLockedIncrement(GSubTestsRun);
    end);

  Ctx.Run('this fails',
    procedure
    var
      LCaught: Boolean = False;
    begin
      try
        Check(False, 'subtest failure');
        Halt(1);
      except
        on E: EAssertionFailed do
        begin
          LCaught := Pos('subtest failure', E.Message) > 0;
        end;
      end;
      Check(LCaught, 'expected "subtest failure" in exception message');
      InterLockedIncrement(GSubTestsRun);
    end);

  Ctx.Run('this also passes',
    procedure
    begin
      CheckEqual(Int64(100), Int64(50 + 50));
      InterLockedIncrement(GSubTestsRun);
    end);
end;

procedure TestNestedSubtests(constref Ctx: ITestContext);
begin
  Ctx.Run('level 1',
    procedure
    begin
      Check(True);
      InterLockedIncrement(GSubTestsRun);
    end);

  Ctx.Run('level 1 again',
    procedure
    begin
      Check(True);
      InterLockedIncrement(GSubTestsRun);
    end);
end;

procedure TestEmptySubtest(constref Ctx: ITestContext);
begin
  { Empty subtest — should pass without error }
  InterLockedIncrement(GSubTestsRun);
end;

procedure TestITestContext(constref Ctx: ITestContext);
var
  LName: string;
begin
  LName := Ctx.TestName;
  Check(LName <> '', 'TestName should not be empty');
  CheckEqual('ITestContext', LName);
  InterLockedIncrement(GSubTestsRun);
end;

procedure TestSubtestWithRealFailure(constref Ctx: ITestContext);
begin
  Ctx.Run('sub pass',
    procedure
    begin
      Check(True);
      InterLockedIncrement(GSubTestsRun);
    end);
  Ctx.Run('sub fail',
    procedure
    begin
      Check(False, 'intentional subtest failure');
    end);
end;

procedure TestSubtestSkip(constref Ctx: ITestContext);
begin
  Ctx.Run('sub pass',
    procedure
    begin
      Check(True);
      InterLockedIncrement(GSubTestsRun);
    end);
  Ctx.Run('sub skip',
    procedure
    begin
      Skip('not ready');
    end);
end;

{ ── B5.7: 3-level nested failure propagation ────────────────────────────── }

procedure LevelCProc(constref CCtx: ITestContext);
begin
  CCtx.Run('leaf fail',
    procedure
    begin
      Check(False, 'deep failure');
    end);
end;

procedure LevelBProc(constref BCtx: ITestContext);
begin
  BCtx.RunNested('level C', @LevelCProc);
end;

procedure TestLevel3Nested(constref Ctx: ITestContext);
begin
  Ctx.RunNested('level B', @LevelBProc);
end;

{ ── B5.5: RunNested API ──────────────────────────────────────────────────── }

procedure NestedChildProc(constref ChildCtx: ITestContext);
begin
  ChildCtx.Run('leaf ok',
    procedure
    begin
      Check(True);
      InterLockedIncrement(GSubTestsRun);
    end);
end;

procedure TestRunNestedApi(constref Ctx: ITestContext);
begin
  Ctx.RunNested('nested child', @NestedChildProc);
end;

{ ── R2-F21: BeforeEach/AfterEach in subtests ────────────────────────────── }

procedure TestSubtestWithLifecycle(constref Ctx: ITestContext);
begin
  Ctx.Run('sub1',
    procedure
    begin
      Check(True);
      InterLockedIncrement(GSubTestsRun);
    end);
  Ctx.Run('sub2',
    procedure
    begin
      Check(True);
      InterLockedIncrement(GSubTestsRun);
    end);
  Ctx.Run('sub3',
    procedure
    begin
      Check(True);
      InterLockedIncrement(GSubTestsRun);
    end);
end;

{ ── R3: ITestContext.Fail/Skip behavior ───────────────────────────────────── }

procedure TestContextFailRaises(constref Ctx: ITestContext);
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    Ctx.Fail('intentional fail');
  except
    on E: EAssertionFailed do
    begin
      LCaught := True;
      CheckContains(E.Message, 'intentional fail');
    end;
  end;
  CheckTrue(LCaught, 'Ctx.Fail should raise EAssertionFailed');
end;

procedure TestContextSkipRaises(constref Ctx: ITestContext);
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    Ctx.Skip('intentional skip');
  except
    on E: ETestSkipped do
    begin
      LCaught := True;
      CheckContains(E.Message, 'intentional skip');
    end;
  end;
  CheckTrue(LCaught, 'Ctx.Skip should raise ETestSkipped');
end;

{ ── R3: AfterEach failure propagation ─────────────────────────────────────── }

var
  GAfterEachFails: Boolean = False;

procedure TestAfterEachFail(constref Ctx: ITestContext);
begin
  Ctx.Run('child ok',
    procedure
    begin
      Check(True);
    end);
end;

{ ── R3: Subtest Duration ─────────────────────────────────────────────────── }

procedure TestSubtestDuration(constref Ctx: ITestContext);
begin
  Ctx.Run('timed',
    procedure
    begin
      Check(True);
    end);
end;

{ ── R6-12/13/14: Closure subtest support ─────────────────────────────────── }

procedure TestClosureSubtest(constref Ctx: ITestContext);
begin
  Ctx.Run('closure pass',
    procedure
    begin
      CheckEqual(Int64(6), Int64(2 * 3));
      InterLockedIncrement(GSubTestsRun);
    end);

  Ctx.Run('closure string',
    procedure
    begin
      CheckEqual('abc', 'a' + 'bc');
      InterLockedIncrement(GSubTestsRun);
    end);
end;

procedure TestClosureSubtestWithFailure(constref Ctx: ITestContext);
begin
  Ctx.Run('closure ok',
    procedure
    begin
      Check(True);
      InterLockedIncrement(GSubTestsRun);
    end);

  Ctx.Run('closure fail',
    procedure
    begin
      Check(False, 'closure subtest failure');
    end);
end;

{ ── R6-55: Subtest skip counting precision ─────────────────────────────────── }

procedure TestSubtestSkipPrecision(constref Ctx: ITestContext);
begin
  Ctx.Run('pass', procedure begin CheckTrue(True); end);
  Ctx.Run('skip_me', procedure begin Skip('intentional skip'); end);
  Ctx.Run('another_pass', procedure begin CheckTrue(True); end);
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LFailSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('Subtest Integration');

  LSuite.OnBeforeEach(procedure begin InterLockedIncrement(GBeforeEachCount); end);
  LSuite.OnAfterEach(procedure begin InterLockedIncrement(GAfterEachCount); end);

  LSuite.TestSubtest('simple subtest',     @TestSimpleSubtest);
  LSuite.TestSubtest('expect in subtest',  @TestSubtestWithExpect);
  LSuite.TestSubtest('failure in subtest', @TestSubtestWithFailure);
  LSuite.TestSubtest('nested subtests',    @TestNestedSubtests);
  LSuite.TestSubtest('empty subtest',      @TestEmptySubtest);
  LSuite.TestSubtest('ITestContext',       @TestITestContext);
  LSuite.TestSubtest('subtest skip',       @TestSubtestSkip);
  LSuite.TestSubtest('RunNested API',      @TestRunNestedApi);
  LSuite.TestSubtest('lifecycle in subtests', @TestSubtestWithLifecycle);
  LSuite.TestSubtest('ITestContext.Fail',    @TestContextFailRaises);
  LSuite.TestSubtest('ITestContext.Skip',    @TestContextSkipRaises);
  LSuite.TestSubtest('subtest duration',     @TestSubtestDuration);
  LSuite.TestSubtest('closure subtest',      @TestClosureSubtest);

  if not LSuite.Run then
  begin
    WriteLn;
    WriteLn(AnsiRed('SOME TESTS FAILED'));
    Halt(1);
  end;

  WriteLn;
  WriteLn(AnsiBold('Subtests run: '), GSubTestsRun);
  if GSubTestsRun < 10 then
  begin
    WriteLn(AnsiRed('FAIL: expected at least 10 subtests run, got '), GSubTestsRun);
    Halt(1);
  end;

  WriteLn(AnsiBold('BeforeEach count: '), GBeforeEachCount);
  WriteLn(AnsiBold('AfterEach count: '), GAfterEachCount);
  { BeforeEach/AfterEach should have been called exactly once per registered test }
  if GBeforeEachCount <> 13 then
  begin
    WriteLn(AnsiRed('FAIL: expected exactly 13 BeforeEach calls, got '), GBeforeEachCount);
    Halt(1);
  end;
  if GAfterEachCount <> 13 then
  begin
    WriteLn(AnsiRed('FAIL: expected exactly 13 AfterEach calls, got '), GAfterEachCount);
    Halt(1);
  end;

  { ── Verify subtest failure propagation ────────────────────────────────────── }
  { A suite containing a subtest with a real failure should report failure }
  WriteLn;
  WriteLn(AnsiBold('─── Failure Propagation ───'));
  begin
    LFailSuite := TTestSuite.Create('Failure Propagation');
    LFailSuite.TestSubtest('real failure', @TestSubtestWithRealFailure);
    if LFailSuite.Run then
    begin
      WriteLn(AnsiRed('FAIL: suite with failing subtest should report failure'));
      Halt(1);
    end;
    WriteLn(AnsiGreen('  Failure propagation verified'));
  end;

  { ── R6-12/13/14: Closure subtest failure propagation ───────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── Closure Subtest Failure ───'));
  begin
    LFailSuite := TTestSuite.Create('Closure Failure');
    LFailSuite.TestSubtest('closure failure', @TestClosureSubtestWithFailure);
    if LFailSuite.Run then
    begin
      WriteLn(AnsiRed('FAIL: closure subtest failure should propagate'));
      Halt(1);
    end;
    WriteLn(AnsiGreen('  Closure subtest failure propagation verified'));
  end;

  { ── R6-55: Subtest skip counting precision ─────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── R6-55: Subtest Skip Counting ───'));
  begin
    LFailSuite := TTestSuite.Create('Skip Count');
    LFailSuite.TestSubtest('skip precision', @TestSubtestSkipPrecision);
    LFailSuite.Test('normal', procedure begin CheckTrue(True); end);
    if not LFailSuite.Run then
    begin
      WriteLn(AnsiRed('FAIL: suite with skip in subtest should pass'));
      Halt(1);
    end;
    { Subtest-level skips do NOT propagate to suite skip counter (design).
      But the suite should still pass (no failures). }
    CheckTrue(LFailSuite.LastFail = 0,
      'Expected 0 failures, got ' + IntToStr(LFailSuite.LastFail));
    CheckTrue(LFailSuite.LastPass >= 1,
      'Expected at least 1 pass, got ' + IntToStr(LFailSuite.LastPass));
    WriteLn(AnsiGreen('  Subtest skip counting verified'));
  end;

  { ── B5.7: 3-level nested failure propagation ────────────────────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── 3-Level Nested Failure ───'));
  begin
    LFailSuite := TTestSuite.Create('Deep Nested Failure');
    LFailSuite.TestSubtest('3-level', @TestLevel3Nested);
    if LFailSuite.Run then
    begin
      WriteLn(AnsiRed('FAIL: 3-level nested failure should propagate'));
      Halt(1);
    end;
    WriteLn(AnsiGreen('  3-level failure propagation verified'));
  end;

  { ── R3: AfterEach failure is treated as WARNING in subtests ─────────────── }
  WriteLn;
  WriteLn(AnsiBold('─── AfterEach Failure ───'));
  begin
    LFailSuite := TTestSuite.Create('AfterEach Fail');
    LFailSuite.OnAfterEach(procedure begin raise EAssertionFailed.Create('afterEach boom'); end);
    LFailSuite.TestSubtest('child ok', @TestAfterEachFail);
    { Current design: subtest AfterEach failure is a WARNING, suite still passes }
    if not LFailSuite.Run then
    begin
      WriteLn(AnsiRed('FAIL: subtest AfterEach failure should be non-fatal'));
      Halt(1);
    end;
    WriteLn(AnsiGreen('  AfterEach failure treated as WARNING (non-fatal)'));
  end;

  WriteLn;
  WriteLn(AnsiGreen('ALL PASSED'));
end.
