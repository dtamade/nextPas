{ test_subtests — Validates nested subtest execution }
program test_subtests;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
  nextpas.core.test;

var
  GSubTestsRun: Integer = 0;

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

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LFailSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('Subtest Integration');

  LSuite.TestSubtest('simple subtest',     @TestSimpleSubtest);
  LSuite.TestSubtest('expect in subtest',  @TestSubtestWithExpect);
  LSuite.TestSubtest('failure in subtest', @TestSubtestWithFailure);
  LSuite.TestSubtest('nested subtests',    @TestNestedSubtests);
  LSuite.TestSubtest('empty subtest',      @TestEmptySubtest);
  LSuite.TestSubtest('ITestContext',       @TestITestContext);
  LSuite.TestSubtest('subtest skip',       @TestSubtestSkip);
  LSuite.TestSubtest('RunNested API',      @TestRunNestedApi);

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

  WriteLn;
  WriteLn(AnsiGreen('ALL PASSED'));
end.
