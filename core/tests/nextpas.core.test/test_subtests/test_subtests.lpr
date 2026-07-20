{ test_subtests — Validates nested subtest execution }
program test_subtests;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.fs,
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

procedure TestSubtestSinkPropagation(constref Ctx: ITestContext);
begin
  Ctx.Run('captured_pass',
    procedure
    begin
      CheckTrue(True);
    end);
  Ctx.Run('captured_skip',
    procedure
    begin
      Skip('planned');
    end);
end;

{ ── Phase 2: Log capture ───────────────────────────────────────────────────── }

procedure TestLogCapture(constref Ctx: ITestContext);
begin
  Ctx.Run('log and pass',
    procedure
    begin
      Ctx.Log('hello from subtest');
      Ctx.Logf('value = %d', [42]);
      CheckTrue(True);
    end);
  Ctx.Run('log and fail',
    procedure
    begin
      Ctx.Log('debug info line 1');
      Ctx.Logf('computed %d + %d = %d', [1, 2, 3]);
      CheckFalse(True, 'intentional log failure');
    end);
end;

{ ── Phase 2: Cleanup callbacks ─────────────────────────────────────────────── }

var
  GCleanupOrder: specialize TArray<string>;

procedure TestCleanupBasic(constref Ctx: ITestContext);
begin
  Ctx.OnCleanup(procedure begin
    SetLength(GCleanupOrder, Length(GCleanupOrder) + 1);
    GCleanupOrder[High(GCleanupOrder)] := 'cleanup-A';
  end);
  Ctx.OnCleanup(procedure begin
    SetLength(GCleanupOrder, Length(GCleanupOrder) + 1);
    GCleanupOrder[High(GCleanupOrder)] := 'cleanup-B';
  end);
  Ctx.Run('pass',
    procedure
    begin
      CheckTrue(True);
    end);
end;

procedure TestCleanupOnFailure(constref Ctx: ITestContext);
begin
  Ctx.OnCleanup(procedure begin
    SetLength(GCleanupOrder, Length(GCleanupOrder) + 1);
    GCleanupOrder[High(GCleanupOrder)] := 'failure-cleanup';
  end);
  Ctx.Run('fail',
    procedure
    begin
      CheckFalse(True, 'intentional cleanup failure test');
    end);
end;

procedure TestCleanupExceptionSwallowed(constref Ctx: ITestContext);
begin
  Ctx.OnCleanup(procedure begin
    raise EAssertionFailed.Create('cleanup boom');
  end);
  Ctx.Run('pass',
    procedure
    begin
      CheckTrue(True);
    end);
end;

{ ── R51: TempDir tests ──────────────────────────────────────────────────────── }

procedure TestTempDirCreation(constref Ctx: ITestContext);
var
  LDir: string;
begin
  Ctx.Run('creates temp dir',
    procedure
    begin
      LDir := Ctx.TempDir;
      CheckTrue(LDir <> '', 'TempDir should not be empty');
      CheckTrue(DirectoryExists(LDir), 'TempDir should exist');
    end);
  Ctx.Run('returns same dir on second access',
    procedure
    var
      LDir2: string;
    begin
      LDir2 := Ctx.TempDir;
      CheckEqual(Ctx.TempDir, LDir2, 'TempDir should return same path');
    end);
  Ctx.Run('can create files in temp dir',
    procedure
    var
      LFilePath: string;
      LF: TextFile;
    begin
      LFilePath := Ctx.TempDir + '/test_file.txt';
      AssignFile(LF, LFilePath);
      Rewrite(LF);
      WriteLn(LF, 'hello');
      CloseFile(LF);
      CheckTrue(FileExists(LFilePath), 'file should exist in temp dir');
    end);
end;

{ ── R52: WithTempDir helper ─────────────────────────────────────────────────── }

procedure TestWithTempDirProc(const ADir: string);
var
  LF: TextFile;
begin
  CheckTrue(ADir <> '', 'dir should not be empty');
  CheckTrue(DirectoryExists(ADir), 'dir should exist');
  { Create a file inside }
  AssignFile(LF, ADir + '/test.txt');
  Rewrite(LF);
  WriteLn(LF, 'hello');
  CloseFile(LF);
  CheckTrue(FileExists(ADir + '/test.txt'), 'file should exist');
end;

procedure TestWithTempDir;
var
  LCreated: Boolean;
begin
  LCreated := False;
  WithTempDir(@TestWithTempDirProc);
  CheckTrue(True, 'WithTempDir completed');
end;

{ ── B20 meta harnesses (Suite.Test wrappers for scale + contracts) ───────── }

procedure HarnessFailurePropagation;
var
  LFailSuite: TTestSuite;
begin
  LFailSuite := TTestSuite.Create('Failure Propagation');
  LFailSuite.TestSubtest('real failure', @TestSubtestWithRealFailure);
  CheckFalse(LFailSuite.Run, 'suite with failing subtest should report failure');
  LFailSuite := Default(TTestSuite);
end;

procedure HarnessClosureSubtestFailure;
var
  LFailSuite: TTestSuite;
begin
  LFailSuite := TTestSuite.Create('Closure Failure');
  LFailSuite.TestSubtest('closure failure', @TestClosureSubtestWithFailure);
  CheckFalse(LFailSuite.Run, 'closure subtest failure should propagate');
  LFailSuite := Default(TTestSuite);
end;

procedure HarnessSubtestSkipCounting;
var
  LFailSuite: TTestSuite;
begin
  LFailSuite := TTestSuite.Create('Skip Count');
  LFailSuite.TestSubtest('skip precision', @TestSubtestSkipPrecision);
  LFailSuite.Test('normal', procedure begin CheckTrue(True); end);
  CheckTrue(LFailSuite.Run, 'suite with skip in subtest should pass');
  CheckEqual(LFailSuite.LastFail, 0, 'Expected 0 failures');
  CheckTrue(LFailSuite.LastPass >= 1, 'Expected at least 1 pass');
  LFailSuite := Default(TTestSuite);
end;

procedure Harness3LevelNestedFailure;
var
  LFailSuite: TTestSuite;
begin
  LFailSuite := TTestSuite.Create('Deep Nested Failure');
  LFailSuite.TestSubtest('3-level', @TestLevel3Nested);
  CheckFalse(LFailSuite.Run, '3-level nested failure should propagate');
  LFailSuite := Default(TTestSuite);
end;

procedure HarnessAfterEachWarning;
var
  LFailSuite: TTestSuite;
begin
  LFailSuite := TTestSuite.Create('AfterEach Fail');
  LFailSuite.OnAfterEach(procedure
    begin
      raise EAssertionFailed.Create('afterEach boom');
    end);
  LFailSuite.TestSubtest('child ok', @TestAfterEachFail);
  CheckTrue(LFailSuite.Run, 'subtest AfterEach failure should be non-fatal');
  LFailSuite := Default(TTestSuite);
end;

procedure HarnessSubtestSinkPropagation;
var
  LFailSuite: TTestSuite;
  LOutSink, LErrSink: TBufferSink;
  LOutput: string;
begin
  LOutSink := TBufferSink.Create;
  LErrSink := TBufferSink.Create;
  LFailSuite := TTestSuite.Create('Subtest Sink');
  LFailSuite.Config.OutSink := LOutSink;
  LFailSuite.Config.ErrSink := LErrSink;
  LFailSuite.Config.AnsiMode := amOff;
  LFailSuite.TestSubtest('parent', @TestSubtestSinkPropagation);
  CheckTrue(LFailSuite.Run, 'subtest sink suite should pass');
  LOutput := LOutSink.GetOutput;
  CheckTrue(Pos('parent/captured_pass', LOutput) > 0, 'captured_pass in sink');
  CheckTrue(Pos('parent/captured_skip', LOutput) > 0, 'captured_skip in sink');
  CheckEqual(LErrSink.GetOutput, '', 'err sink empty');
  LFailSuite := Default(TTestSuite);
  LOutSink := nil;
  LErrSink := nil;
end;

procedure HarnessCleanupReverseOrder;
var
  LFailSuite: TTestSuite;
begin
  GCleanupOrder := nil;
  LFailSuite := TTestSuite.Create('Cleanup Order');
  LFailSuite.Config.OutSink := TBufferSink.Create;
  LFailSuite.Config.ErrSink := TBufferSink.Create;
  LFailSuite.Config.AnsiMode := amOff;
  LFailSuite.TestSubtest('cleanup basic', @TestCleanupBasic);
  CheckTrue(LFailSuite.Run, 'cleanup basic should pass');
  CheckEqual(Length(GCleanupOrder), 2, '2 cleanups');
  CheckEqual(GCleanupOrder[0], 'cleanup-B', 'reverse B first');
  CheckEqual(GCleanupOrder[1], 'cleanup-A', 'reverse A second');
  LFailSuite := Default(TTestSuite);
end;

procedure HarnessCleanupOnFailure;
var
  LFailSuite: TTestSuite;
begin
  GCleanupOrder := nil;
  LFailSuite := TTestSuite.Create('Cleanup On Failure');
  LFailSuite.Config.OutSink := TBufferSink.Create;
  LFailSuite.Config.ErrSink := TBufferSink.Create;
  LFailSuite.Config.AnsiMode := amOff;
  LFailSuite.TestSubtest('cleanup failure', @TestCleanupOnFailure);
  CheckFalse(LFailSuite.Run, 'failing subtest suite fails');
  CheckEqual(Length(GCleanupOrder), 1);
  CheckEqual(GCleanupOrder[0], 'failure-cleanup');
  LFailSuite := Default(TTestSuite);
end;

procedure HarnessCleanupExceptionSwallowed;
var
  LFailSuite: TTestSuite;
  LOutSink, LErrSink: TBufferSink;
  LOutput: string;
begin
  LFailSuite := TTestSuite.Create('Cleanup Swallow');
  LOutSink := TBufferSink.Create;
  LErrSink := TBufferSink.Create;
  LFailSuite.Config.OutSink := LOutSink;
  LFailSuite.Config.ErrSink := LErrSink;
  LFailSuite.Config.AnsiMode := amOff;
  LFailSuite.TestSubtest('cleanup exception', @TestCleanupExceptionSwallowed);
  CheckTrue(LFailSuite.Run, 'cleanup exception swallowed');
  LOutput := LErrSink.GetOutput;
  CheckTrue(Pos('WARNING cleanup error', LOutput) > 0, 'WARNING cleanup error');
  LFailSuite := Default(TTestSuite);
  LOutSink := nil;
  LErrSink := nil;
end;

procedure HarnessLogOutputOnFailure;
var
  LFailSuite: TTestSuite;
  LOutSink, LErrSink: TBufferSink;
  LOutput: string;
begin
  LFailSuite := TTestSuite.Create('Log On Failure');
  LOutSink := TBufferSink.Create;
  LErrSink := TBufferSink.Create;
  LFailSuite.Config.OutSink := LOutSink;
  LFailSuite.Config.ErrSink := LErrSink;
  LFailSuite.Config.AnsiMode := amOff;
  LFailSuite.TestSubtest('log test', @TestLogCapture);
  CheckFalse(LFailSuite.Run, 'failing log suite');
  LOutput := LOutSink.GetOutput;
  CheckTrue(Pos('debug info line 1', LOutput) > 0);
  CheckTrue(Pos('computed 1 + 2 = 3', LOutput) > 0);
  CheckTrue(Pos('hello from subtest', LOutput) = 0,
    'passing subtest log should not appear');
  LFailSuite := Default(TTestSuite);
  LOutSink := nil;
  LErrSink := nil;
end;

procedure HarnessSoftFailInSubtest;
{ v8.21 Go t.Run layering: parent SoftFail preserved; leaf SoftFail on leaf result. }
var
  LFailSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LParentMsg, LLeafMsg: string;
  LLeafFailed: Boolean;
begin
  LFailSuite := TTestSuite.Create('SoftFail Subtest');
  LFailSuite.TestSubtest('soft sub',
    procedure(constref Ctx: ITestContext)
    begin
      SoftFail('sub soft 1');
      SoftCheckEqual('a', 'b', 'sub soft str');
      Ctx.Run('leaf', procedure
        begin
          SoftFail('leaf soft');
        end);
    end);
  CheckFalse(LFailSuite.RunWithResult(LResult), 'soft subtest fails suite');
  CheckTrue(LResult.Failed >= 1);
  LParentMsg := '';
  LLeafMsg := '';
  LLeafFailed := False;
  for I := 0 to High(LResult.Results) do
  begin
    if LResult.Results[I].Name = 'soft sub' then
    begin
      CheckEqual(Ord(tsFailed), Ord(LResult.Results[I].Status));
      LParentMsg := LResult.Results[I].Message;
    end
    else if LResult.Results[I].Name = 'soft sub/leaf' then
    begin
      LLeafMsg := LResult.Results[I].Message;
      LLeafFailed := LResult.Results[I].Status = tsFailed;
    end;
  end;
  CheckTrue(LLeafFailed, 'leaf SoftFail marks leaf tsFailed');
  CheckEqual('leaf soft', LLeafMsg, 'leaf SoftFail message exact');
  { Parent keeps its soft join; child fail also surfaces via subtest aggregate. }
  CheckContains(LParentMsg, 'sub soft 1');
  CheckContains(LParentMsg, 'sub soft str');
  LFailSuite := Default(TTestSuite);
end;

procedure HarnessSoftFailTopLevelExact;
{ SoftFail only on top-level TestSubtest body (no nested Run) → full join. }
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
begin
  LSuite := TTestSuite.Create('soft-top');
  LSuite.TestSubtest('only soft',
    procedure(constref Ctx: ITestContext)
    begin
      SoftFail('alpha');
      SoftFail('beta');
      SoftCheckTrue(False, 'gamma');
    end);
  CheckFalse(LSuite.RunWithResult(LResult));
  CheckEqual(1, LResult.Failed);
  CheckEqual('alpha; beta; gamma', LResult.Results[0].Message,
    'top-level TestSubtest SoftFail join exact');
  LSuite := Default(TTestSuite);
end;

procedure HarnessSoftFailLeafMultiExact;
{ Multiple SoftFail inside leaf → leaf Message is join; parent fails via aggregate. }
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LLeafMsg, LParentMsg: string;
begin
  LSuite := TTestSuite.Create('soft-leaf-multi');
  LSuite.TestSubtest('parent',
    procedure(constref Ctx: ITestContext)
    begin
      Ctx.Run('leaf', procedure
        begin
          SoftFail('L1');
          SoftFail('L2');
        end);
    end);
  CheckFalse(LSuite.RunWithResult(LResult));
  LLeafMsg := '';
  LParentMsg := '';
  for I := 0 to High(LResult.Results) do
  begin
    if LResult.Results[I].Name = 'parent/leaf' then
      LLeafMsg := LResult.Results[I].Message
    else if LResult.Results[I].Name = 'parent' then
      LParentMsg := LResult.Results[I].Message;
  end;
  CheckEqual('L1; L2', LLeafMsg, 'leaf multi SoftFail join on leaf');
  CheckTrue(
    (Pos('subtest', LowerCase(LParentMsg)) > 0) or (LParentMsg <> ''),
    'parent fails because child soft-failed: ' + LParentMsg);
  LSuite := Default(TTestSuite);
end;

{ B33 table cases capture AC via threadvar-free globals (FPC nested ref limits). }
var
  GB33Mode: string;
  GB33Tag: string;

procedure B33LeafSoftOnly;
begin
  SoftFail('sf-' + GB33Tag);
end;

procedure B33LeafSoft2;
begin
  SoftFail('a-' + GB33Tag);
  SoftFail('b-' + GB33Tag);
end;

procedure B33LeafHard;
begin
  CheckTrue(False, 'hard-' + GB33Tag);
end;

procedure B33ParentSoftFailPath(constref Ctx: ITestContext);
begin
  if GB33Mode = 'soft' then
    Ctx.Run('leaf', @B33LeafSoftOnly)
  else if GB33Mode = 'soft2' then
    Ctx.Run('leaf', @B33LeafSoft2)
  else
    Ctx.Run('leaf', @B33LeafHard);
end;

procedure TestB33SoftFailPathCase(const AC: TTestCase);
{ Data: soft | soft2 | hard — SoftFail/hard inside leaf under TestSubtest. }
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LMsg: string;
begin
  GB33Mode := AC.Data;
  GB33Tag := AC.Name;
  LSuite := TTestSuite.Create('b33-' + AC.Name);
  LSuite.TestSubtest('p', @B33ParentSoftFailPath);
  CheckFalse(LSuite.RunWithResult(LResult), 'fail-path ' + AC.Name);
  LMsg := '';
  for I := 0 to High(LResult.Results) do
    if LResult.Results[I].Name = 'p' then
      LMsg := LResult.Results[I].Message;
  if AC.Data = 'soft' then
  begin
    { soft on leaf: leaf message exact; parent aggregates }
    LMsg := '';
    for I := 0 to High(LResult.Results) do
      if LResult.Results[I].Name = 'p/leaf' then
        LMsg := LResult.Results[I].Message;
    CheckEqual('sf-' + AC.Name, LMsg, 'soft exact on leaf')
  end
  else if AC.Data = 'soft2' then
  begin
    LMsg := '';
    for I := 0 to High(LResult.Results) do
      if LResult.Results[I].Name = 'p/leaf' then
        LMsg := LResult.Results[I].Message;
    CheckEqual('a-' + AC.Name + '; b-' + AC.Name, LMsg, 'soft2 join on leaf')
  end
  else
    { hard in leaf → parent aggregates; message contains hard tag or subtest summary }
    CheckTrue(
      (Pos('hard-' + AC.Name, LMsg) > 0) or
      (Pos('subtest', LowerCase(LMsg)) > 0),
      'hard fail-path msg: ' + LMsg);
  LSuite := Default(TTestSuite);
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LMeta: TTestSuite;
  LB33Cases: specialize TArray<TTestCase>;
  LB33I: Integer;
begin
  WriteLn('=== test_subtests ===');
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
  LSuite.TestSubtest('TempDir',              @TestTempDirCreation);
  LSuite.Test('WithTempDir',                   @TestWithTempDir);

  if not LSuite.Run then
  begin
    WriteLn;
    FailTest('SOME TESTS FAILED');
  end;

  WriteLn;
  WriteLn(AnsiBold('Subtests run: '), GSubTestsRun);
  CheckTrue(GSubTestsRun >= 10, 'expected at least 10 subtests run');
  WriteLn(AnsiBold('BeforeEach count: '), GBeforeEachCount);
  WriteLn(AnsiBold('AfterEach count: '), GAfterEachCount);
  CheckEqual(GBeforeEachCount, 15, 'BeforeEach per registered entry');
  CheckEqual(GAfterEachCount, 15, 'AfterEach per registered entry');

  { B20: meta contracts as Suite.Test for scale + t.Run depth }
  WriteLn;
  SectionHeader('B20 meta contracts (t.Run depth)');
  LMeta := TTestSuite.Create('subtest-meta');
  LMeta.Test('Failure propagation', @HarnessFailurePropagation);
  LMeta.Test('Closure subtest failure', @HarnessClosureSubtestFailure);
  LMeta.Test('Subtest skip counting', @HarnessSubtestSkipCounting);
  LMeta.Test('3-level nested failure', @Harness3LevelNestedFailure);
  LMeta.Test('AfterEach warning', @HarnessAfterEachWarning);
  LMeta.Test('Sink propagation', @HarnessSubtestSinkPropagation);
  LMeta.Test('Cleanup reverse order', @HarnessCleanupReverseOrder);
  LMeta.Test('Cleanup on failure', @HarnessCleanupOnFailure);
  LMeta.Test('Cleanup exception swallowed', @HarnessCleanupExceptionSwallowed);
  LMeta.Test('Log output on failure', @HarnessLogOutputOnFailure);
  LMeta.Test('SoftFail in subtest', @HarnessSoftFailInSubtest);
  LMeta.Test('SoftFail top-level exact', @HarnessSoftFailTopLevelExact);
  LMeta.Test('SoftFail leaf multi exact', @HarnessSoftFailLeafMultiExact);
  { B33 fail-path table }
  SetLength(LB33Cases, 48);
  for LB33I := 0 to High(LB33Cases) do
  begin
    LB33Cases[LB33I].Name := 's' + IntToStr(LB33I);
    case LB33I mod 3 of
      0: LB33Cases[LB33I].Data := 'soft';
      1: LB33Cases[LB33I].Data := 'soft2';
    else
      LB33Cases[LB33I].Data := 'hard';
    end;
  end;
  LMeta.TestTable('B33 SoftFail subtest fail-path', LB33Cases, @TestB33SoftFailPathCase);
  if not LMeta.Run then
  begin
    WriteLn;
    FailTest('META CONTRACTS FAILED');
  end;

  WriteLn;
  PassTest('ALL PASSED');

  LMeta := Default(TTestSuite);
  LSuite := Default(TTestSuite);
end.
