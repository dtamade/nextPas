{ test_runner — Validates TTestRunner multi-suite + subtests + lifecycle }
program test_runner;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  SysUtils,
  nextpas.core.test;

var
  GSetupCalled: Integer = 0;
  GTeardownCalled: Integer = 0;
  GBeforeEachCalled: Integer = 0;
  GAfterEachCalled: Integer = 0;

{ ── Lifecycle tests ──────────────────────────────────────────────────────── }

procedure TestSetup;
begin
  CheckTrue(GSetupCalled > 0, 'Setup should have been called');
end;

procedure TestBeforeEach;
begin
  CheckTrue(GBeforeEachCalled > 0, 'BeforeEach should have been called');
end;

procedure TestAfterEach1;
begin
  { AfterEach is checked after each test via counters }
  CheckTrue(True);
end;

procedure TestAfterEach2;
begin
  CheckTrue(True);
end;

{ ── Subtest tests ────────────────────────────────────────────────────────── }

procedure TestSubtests(constref Ctx: ITestContext);
begin
  Ctx.Run('sub 1',
    procedure
    begin
      CheckEqual(Int64(1), Int64(1));
    end);

  Ctx.Run('sub 2',
    procedure
    begin
      CheckTrue(True);
    end);

  Ctx.Run('sub 3: deeper',
    procedure
    begin
      CheckContains('hello world', 'world');
    end);
end;

procedure TestSubtestsWithFailure(constref Ctx: ITestContext);
begin
  Ctx.Run('pass',
    procedure
    begin
      Check(True);
    end);

  Ctx.Run('expected fail',
    procedure
    begin
      try
        Check(False, 'sub-assertion');
        Halt(1);
      except
        on E: EAssertionFailed do
          Check(Pos('sub-assertion', E.Message) > 0);
      end;
    end);
end;

{ ── Skip test ────────────────────────────────────────────────────────────── }

procedure TestSkipInSuite;
begin
  Skip('intentionally skipped for testing');
  Halt(1); { Should never reach }
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite1, LSuite2: TTestSuite;
  LRunner: TTestRunner;
  LPass: Boolean;
begin
  { Suite 1: lifecycle }
  LSuite1 := TTestSuite.Create('Lifecycle');
  LSuite1.SetSetup(procedure begin Inc(GSetupCalled); end);
  LSuite1.SetTeardown(procedure begin Inc(GTeardownCalled); end);
  LSuite1.OnBeforeEach(procedure begin Inc(GBeforeEachCalled); end);
  LSuite1.OnAfterEach(procedure begin Inc(GAfterEachCalled); end);

  LSuite1.Test('setup was called',    @TestSetup);
  LSuite1.Test('beforeEach called',   @TestBeforeEach);
  LSuite1.Test('afterEach test 1',    @TestAfterEach1);
  LSuite1.Test('afterEach test 2',    @TestAfterEach2);

  { Suite 2: subtests + skip }
  LSuite2 := TTestSuite.Create('Subtests');
  LSuite2.TestSubtest('nested subtests',       @TestSubtests);
  LSuite2.TestSubtest('subtests with failure',  @TestSubtestsWithFailure);
  LSuite2.Skip('planned feature', 'not yet implemented');
  LSuite2.Test('skip in suite',      @TestSkipInSuite);

  { Multi-suite runner }
  LRunner := TTestRunner.Create('Test Runner Integration');
  LRunner.Add(LSuite1);
  LRunner.Add(LSuite2);

  LPass := LRunner.RunAll;

  { Verify lifecycle counters }
  WriteLn;
  WriteLn(AnsiBold('─── Lifecycle Counters ───'));
  WriteLn('  Setup called:     ', GSetupCalled);
  WriteLn('  Teardown called:  ', GTeardownCalled);
  WriteLn('  BeforeEach called:', GBeforeEachCalled);
  WriteLn('  AfterEach called: ', GAfterEachCalled);

  if GSetupCalled < 1 then
  begin
    WriteLn(AnsiRed('FAIL: Setup not called enough'));
    Halt(1);
  end;
  if GTeardownCalled < 1 then
  begin
    WriteLn(AnsiRed('FAIL: Teardown not called enough'));
    Halt(1);
  end;
  if GBeforeEachCalled < 4 then
  begin
    WriteLn(AnsiRed('FAIL: BeforeEach not called for each test'));
    Halt(1);
  end;
  if GAfterEachCalled < 4 then
  begin
    WriteLn(AnsiRed('FAIL: AfterEach not called for each test'));
    Halt(1);
  end;

  if not LPass then
  begin
    WriteLn;
    WriteLn(AnsiRed('SOME TESTS FAILED'));
    Halt(1);
  end;
  WriteLn;
  WriteLn(AnsiGreen('ALL PASSED'));
end.
