{ test_subtests — Validates nested subtest execution }
program test_subtests;

{$mode objfpc}{$H+}{$J-}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.platform.env,
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

procedure B61Level3Soft(constref C3: ITestContext);
begin
  SoftFail('soft-L3-a');
  SoftFail('soft-L3-b');
  C3.Run('leaf',
    procedure
    begin
      SoftFail('soft-leaf');
    end);
end;

procedure B61Level2Soft(constref C2: ITestContext);
begin
  SoftFail('soft-L2');
  SoftCheckEqual(Int64(1), Int64(2), 'soft-L2-eq');
  C2.RunNested('L3', @B61Level3Soft);
end;

procedure B61Level1Soft(constref Ctx: ITestContext);
begin
  SoftFail('soft-L1');
  Ctx.RunNested('L2', @B61Level2Soft);
end;

procedure HarnessB61DeepSoftLayering;
{ v8.28 B61: ≥3-level RunNested SoftFail — leaf exact; mid/parent Soft visible. }
var
  LSuite: TTestSuite;
  LResult: TTestRunResult;
  I: Integer;
  LTopMsg, LMidMsg, LLeafMsg: string;
  LLeafFailed, LMidFailed, LTopFailed, LSawL3: Boolean;
begin
  LSuite := TTestSuite.Create('deep-soft');
  LSuite.TestSubtest('L1', @B61Level1Soft);
  CheckFalse(LSuite.RunWithResult(LResult), 'deep soft suite fails');
  LTopMsg := '';
  LMidMsg := '';
  LLeafMsg := '';
  LLeafFailed := False;
  LMidFailed := False;
  LTopFailed := False;
  LSawL3 := False;
  for I := 0 to High(LResult.Results) do
  begin
    if LResult.Results[I].Name = 'L1' then
    begin
      LTopFailed := LResult.Results[I].Status = tsFailed;
      LTopMsg := LResult.Results[I].Message;
    end
    else if LResult.Results[I].Name = 'L1/L2' then
    begin
      LMidFailed := LResult.Results[I].Status = tsFailed;
      LMidMsg := LResult.Results[I].Message;
    end
    else if LResult.Results[I].Name = 'L1/L2/L3/leaf' then
    begin
      LLeafFailed := LResult.Results[I].Status = tsFailed;
      LLeafMsg := LResult.Results[I].Message;
    end
    else if LResult.Results[I].Name = 'L1/L2/L3' then
    begin
      LSawL3 := True;
      CheckEqual(Ord(tsFailed), Ord(LResult.Results[I].Status), 'L3 failed');
      CheckContains(LResult.Results[I].Message, 'soft-L3-a');
      CheckContains(LResult.Results[I].Message, 'soft-L3-b');
    end;
  end;
  CheckTrue(LLeafFailed, 'leaf SoftFail fails leaf');
  CheckEqual('soft-leaf', LLeafMsg, 'leaf SoftFail message exact');
  CheckTrue(LMidFailed, 'L2 SoftFail fails mid (result collected)');
  CheckContains(LMidMsg, 'soft-L2');
  CheckContains(LMidMsg, 'soft-L2-eq');
  CheckTrue(LSawL3, 'L3 Soft layer in Results');
  CheckTrue(LTopFailed, 'L1 SoftFail fails top');
  CheckContains(LTopMsg, 'soft-L1');
  { Parent soft join must not absorb leaf-only text into top Message. }
  CheckFalse(Pos('soft-leaf', LTopMsg) > 0,
    'top SoftFail join stays parent-local (not leaf text)');
  LSuite := Default(TTestSuite);
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

{ ── v8.39 subtest aggregation / collection / counters / env isolation ─────── }
{ Spec-driven tree builder: GTree* globals drive static node procs because
  TSubtestProc is a plain procedure pointer (no closure capture for RunNested).
  Tokens: p=pass leaf, f=fail leaf (msg 'boom'), s=skip leaf (reason 'why'),
  e=error leaf (Exception 'kaboom'), l=log 2 lines + fail, m=log 1 line + pass,
  A/B=RunNested node expanding GTreeA/GTreeB. Leaf names: token + 1-based
  position among the level's tokens (matches Ctx.Run registration order). }

var
  GTreeRoot, GTreeRoot2, GTreeA, GTreeB: string;
  GEnvOps, GEnvWantInside: string;
  GEnvInFail: Boolean;

function NextTokS(var S: string; ASep: Char): string;
var
  P: Integer;
begin
  P := Pos(ASep, S);
  if P = 0 then
  begin
    Result := S;
    S := '';
  end
  else
  begin
    Result := Copy(S, 1, P - 1);
    S := Copy(S, P + 1, Length(S));
  end;
end;

function NextSegS(var S: string): string;
begin
  Result := NextTokS(S, '|');
  if Result = '-' then Result := '';
end;

procedure AppendSCase(var ACases: specialize TArray<TTestCase>;
  const AName, AData, AFlag: string);
var
  LIdx: Integer;
begin
  LIdx := Length(ACases);
  SetLength(ACases, LIdx + 1);
  ACases[LIdx].Name := AName;
  ACases[LIdx].Data := AData + '|' + AFlag;
end;

procedure TreeExpandSpec(constref Ctx: ITestContext; const ASpec: string); forward;

procedure TreeNodeB(constref Ctx: ITestContext);
begin
  TreeExpandSpec(Ctx, GTreeB);
end;

procedure TreeNodeA(constref Ctx: ITestContext);
begin
  TreeExpandSpec(Ctx, GTreeA);
end;

procedure TreeExpandSpec(constref Ctx: ITestContext; const ASpec: string);
var
  I, LN: Integer;
begin
  LN := 0;
  for I := 1 to Length(ASpec) do
  begin
    Inc(LN);
    case ASpec[I] of
      'p': Ctx.Run('p' + IntToStr(LN), procedure begin CheckTrue(True); end);
      'f': Ctx.Run('f' + IntToStr(LN), procedure begin CheckTrue(False, 'boom'); end);
      's': Ctx.Run('s' + IntToStr(LN), procedure begin Skip('why'); end);
      'e': Ctx.Run('e' + IntToStr(LN), procedure begin
             raise Exception.Create('kaboom');
           end);
      'l': Ctx.Run('l' + IntToStr(LN), procedure begin
             Ctx.Log('line-one'); Ctx.Log('line-two');
             CheckTrue(False, 'logfail');
           end);
      'm': Ctx.Run('m' + IntToStr(LN), procedure begin
             Ctx.Log('quiet-line'); CheckTrue(True);
           end);
      'A': Ctx.RunNested('a', @TreeNodeA);
      'B': Ctx.RunNested('b', @TreeNodeB);
    end;
  end;
end;

procedure TreeRootProc(constref Ctx: ITestContext);
begin
  TreeExpandSpec(Ctx, GTreeRoot);
end;

procedure TreeRoot2Proc(constref Ctx: ITestContext);
begin
  TreeExpandSpec(Ctx, GTreeRoot2);
end;

function BuildTreeAndRun(const ARoot, AA, AB, ARoot2: string;
  AWithPlain: Boolean; out ARes: TTestRunResult): Boolean;
var
  LTreeSuite: TTestSuite;
begin
  GTreeRoot := ARoot;
  GTreeA := AA;
  GTreeB := AB;
  GTreeRoot2 := ARoot2;
  LTreeSuite := TTestSuite.Create('tree');
  LTreeSuite.Config.OutSink := TBufferSink.Create;
  LTreeSuite.Config.ErrSink := TBufferSink.Create;
  LTreeSuite.Config.AnsiMode := amOff;
  LTreeSuite.TestSubtest('root', @TreeRootProc);
  if ARoot2 <> '' then
    LTreeSuite.TestSubtest('root2', @TreeRoot2Proc);
  if AWithPlain then
    LTreeSuite.Test('plain', procedure begin CheckTrue(True); end);
  Result := LTreeSuite.RunWithResult(ARes);
  LTreeSuite := Default(TTestSuite);
end;

procedure RunAggMsgCase(const AC: TTestCase);
{ Data: root|specA|specB|wantOk|wantRootMsg|flag — root aggregate message exact:
  'N subtest(s) failed in root: <full-path1>, <full-path2>' (execution order,
  full paths for direct children only; nested failures collapse to node name). }
var
  LData, LRoot, LA, LB, LWantOk, LWantMsg, LFlag: string;
  LRes: TTestRunResult;
  LOk: Boolean;
begin
  LData := AC.Data;
  LRoot := NextSegS(LData);
  LA := NextSegS(LData);
  LB := NextSegS(LData);
  LWantOk := NextSegS(LData);
  LWantMsg := NextSegS(LData);
  LFlag := LData;
  CheckTrue((LWantOk = 'F') = (LFlag = '0'), 'flag self-check ' + AC.Name);
  LOk := BuildTreeAndRun(LRoot, LA, LB, '', False, LRes);
  CheckTrue(LOk = (LWantOk = 'T'), 'suite ok ' + AC.Name);
  CheckTrue(Length(LRes.Results) >= 1, 'root entry present ' + AC.Name);
  CheckEqual('root', LRes.Results[0].Name, 'root entry first ' + AC.Name);
  CheckEqual(LWantMsg, LRes.Results[0].Message, 'root msg ' + AC.Name);
end;

procedure RunNodeResultCase(const AC: TTestCase);
{ Data: root|specA|specB|node|wantIdx|wantStatus|wantMsg|wantLog|flag —
  RunWithResult collection contract: passing ekSubtest nodes are NOT collected
  (wantStatus '-'); results are post-order (leaf index < parent node index);
  CapturedLog copied only on fail/error. }
var
  LData, LRoot, LA, LB, LNode, LWantIdx, LWantStatus, LWantMsg, LWantLog,
    LFlag: string;
  LRes: TTestRunResult;
  LFoundIdx, I: Integer;
begin
  LData := AC.Data;
  LRoot := NextSegS(LData);
  LA := NextSegS(LData);
  LB := NextSegS(LData);
  LNode := NextSegS(LData);
  LWantIdx := NextSegS(LData);
  LWantStatus := NextSegS(LData);
  LWantMsg := NextSegS(LData);
  LWantLog := NextSegS(LData);
  LFlag := LData;
  CheckTrue(((LWantStatus = '1') or (LWantStatus = '3')) = (LFlag = '0'),
    'flag self-check ' + AC.Name);
  BuildTreeAndRun(LRoot, LA, LB, '', False, LRes);
  LFoundIdx := -1;
  for I := 0 to High(LRes.Results) do
    if LRes.Results[I].Name = LNode then
    begin
      LFoundIdx := I;
      Break;
    end;
  if LWantStatus = '' then
    CheckEqual(-1, LFoundIdx, 'node absent ' + AC.Name)
  else
  begin
    CheckTrue(LFoundIdx >= 0, 'node found ' + AC.Name);
    if LWantIdx <> '' then
      CheckEqual(StrToIntDef(LWantIdx, -99), LFoundIdx, 'node idx ' + AC.Name);
    CheckEqual(StrToIntDef(LWantStatus, -99), Ord(LRes.Results[LFoundIdx].Status),
      'node status ' + AC.Name);
    CheckEqual(LWantMsg, LRes.Results[LFoundIdx].Message, 'node msg ' + AC.Name);
    CheckEqual(StrToIntDef(LWantLog, -99),
      Length(LRes.Results[LFoundIdx].CapturedLog), 'node log ' + AC.Name);
  end;
end;

procedure RunCountCase(const AC: TTestCase);
{ Data: root1|root2|plain|specA|wantOk|pass|fail|skip|flag — suite counters:
  subtest-internal pass/skip invisible to suite Passed/Skipped; a failing
  TestSubtest entry counts exactly 1 Failed regardless of leaf fail count;
  plain Test entries count normally. }
var
  LData, LRoot1, LRoot2, LPlain, LA, LWantOk, LWantPass, LWantFail, LWantSkip,
    LFlag: string;
  LRes: TTestRunResult;
  LOk: Boolean;
begin
  LData := AC.Data;
  LRoot1 := NextSegS(LData);
  LRoot2 := NextSegS(LData);
  LPlain := NextSegS(LData);
  LA := NextSegS(LData);
  LWantOk := NextSegS(LData);
  LWantPass := NextSegS(LData);
  LWantFail := NextSegS(LData);
  LWantSkip := NextSegS(LData);
  LFlag := LData;
  CheckTrue((LWantOk = 'F') = (LFlag = '0'), 'flag self-check ' + AC.Name);
  LOk := BuildTreeAndRun(LRoot1, LA, '', LRoot2, LPlain = 'y', LRes);
  CheckTrue(LOk = (LWantOk = 'T'), 'suite ok ' + AC.Name);
  CheckEqual(StrToIntDef(LWantPass, -99), LRes.Passed, 'passed ' + AC.Name);
  CheckEqual(StrToIntDef(LWantFail, -99), LRes.Failed, 'failed ' + AC.Name);
  CheckEqual(StrToIntDef(LWantSkip, -99), LRes.Skipped, 'skipped ' + AC.Name);
end;

procedure EnvProbeProc(constref Ctx: ITestContext);
var
  LOps, LOp: string;
begin
  LOps := GEnvOps;
  while LOps <> '' do
  begin
    LOp := NextTokS(LOps, ',');
    if LOp = 'sa' then Ctx.SetEnv('NP_V839_ENV', 'aa')
    else if LOp = 'sb' then Ctx.SetEnv('NP_V839_ENV', 'bb')
    else if LOp = 'se' then Ctx.SetEnv('NP_V839_ENV', '')
    else if LOp = 'u' then Ctx.UnsetEnv('NP_V839_ENV');
  end;
  if GEnvWantInside = '' then
    CheckFalse(platform_env_exists('NP_V839_ENV'), 'inside missing')
  else if GEnvWantInside = '~' then
  begin
    CheckTrue(platform_env_exists('NP_V839_ENV'), 'inside exists (empty)');
    CheckEqual('', string(platform_env_get_str('NP_V839_ENV')), 'inside empty');
  end
  else
  begin
    CheckTrue(platform_env_exists('NP_V839_ENV'), 'inside exists');
    CheckEqual(GEnvWantInside, string(platform_env_get_str('NP_V839_ENV')),
      'inside value');
  end;
  if GEnvInFail then
    CheckTrue(False, 'envfail');
end;

procedure RunEnvCase(const AC: TTestCase);
{ Data: init|ops|inFail|wantInside|wantExists|wantValue|flag — SetEnv/UnsetEnv
  isolation state machine: restore in reverse order (double-set restores the
  ORIGINAL value); platform_env_exists distinguishes empty ('~') from missing
  ('-'); restore also runs after a failing subtest body.
  init: x=missing y=empty o='orig'. ops: sa/sb/se=SetEnv aa/bb/'' u=UnsetEnv. }
var
  LData, LInit, LOps, LInFail, LWantInside, LWantExists, LWantValue,
    LFlag: string;
  LEnvSuite: TTestSuite;
  LOk: Boolean;
begin
  LData := AC.Data;
  LInit := NextSegS(LData);
  LOps := NextSegS(LData);
  LInFail := NextSegS(LData);
  LWantInside := NextSegS(LData);
  LWantExists := NextSegS(LData);
  LWantValue := NextSegS(LData);
  LFlag := LData;
  CheckTrue((LInFail = 'F') = (LFlag = '0'), 'flag self-check ' + AC.Name);
  if LInit = 'x' then
    platform_env_unset('NP_V839_ENV')
  else if LInit = 'y' then
    platform_env_set('NP_V839_ENV', '')
  else
    platform_env_set('NP_V839_ENV', 'orig');
  GEnvOps := LOps;
  GEnvInFail := LInFail = 'F';
  GEnvWantInside := LWantInside;
  LEnvSuite := TTestSuite.Create('env-' + AC.Name);
  LEnvSuite.Config.OutSink := TBufferSink.Create;
  LEnvSuite.Config.ErrSink := TBufferSink.Create;
  LEnvSuite.Config.AnsiMode := amOff;
  LEnvSuite.TestSubtest('env', @EnvProbeProc);
  LOk := LEnvSuite.Run;
  CheckTrue(LOk = (LInFail <> 'F'), 'suite ok ' + AC.Name);
  if LWantExists = 'T' then
  begin
    CheckTrue(platform_env_exists('NP_V839_ENV'), 'after exists ' + AC.Name);
    if LWantValue = '~' then
      CheckEqual('', string(platform_env_get_str('NP_V839_ENV')),
        'after empty ' + AC.Name)
    else
      CheckEqual(LWantValue, string(platform_env_get_str('NP_V839_ENV')),
        'after value ' + AC.Name);
  end
  else
    CheckFalse(platform_env_exists('NP_V839_ENV'), 'after missing ' + AC.Name);
  platform_env_unset('NP_V839_ENV');
  LEnvSuite := Default(TTestSuite);
end;

{ ── Main ──────────────────────────────────────────────────────────────────── }

var
  LSuite: TTestSuite;
  LMeta: TTestSuite;
  LB33Cases: specialize TArray<TTestCase>;
  LB33I: Integer;
  LAggCases, LNodeCases, LCntCases, LEnvCases: specialize TArray<TTestCase>;
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
  LMeta.Test('B61 deep Soft layering 3+', @HarnessB61DeepSoftLayering);
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

  { v8.39 表 A：聚合消息 exact（全路径、', ' join、执行序、嵌套折叠只列直接子） }
  AppendSCase(LAggCases, 'am-flat-pass', 'pp|-|-|T|-', '1');
  AppendSCase(LAggCases, 'am-flat-one-fail',
    'pf|-|-|F|1 subtest(s) failed in root: root/f2', '0');
  AppendSCase(LAggCases, 'am-flat-two-fail',
    'ffp|-|-|F|2 subtest(s) failed in root: root/f1, root/f2', '0');
  AppendSCase(LAggCases, 'am-flat-three-fail',
    'fff|-|-|F|3 subtest(s) failed in root: root/f1, root/f2, root/f3', '0');
  AppendSCase(LAggCases, 'am-order-skip-mid-pass',
    'fpf|-|-|F|2 subtest(s) failed in root: root/f1, root/f3', '0');
  AppendSCase(LAggCases, 'am-skip-not-fail', 'sp|-|-|T|-', '1');
  AppendSCase(LAggCases, 'am-skip-fail-mix',
    'sf|-|-|F|1 subtest(s) failed in root: root/f2', '0');
  AppendSCase(LAggCases, 'am-error-counted',
    'e|-|-|F|1 subtest(s) failed in root: root/e1', '0');
  AppendSCase(LAggCases, 'am-error-fail-mix',
    'ef|-|-|F|2 subtest(s) failed in root: root/e1, root/f2', '0');
  AppendSCase(LAggCases, 'am-empty-root', '-|-|-|T|-', '1');
  AppendSCase(LAggCases, 'am-nested-collapse',
    'Ap|pf|-|F|1 subtest(s) failed in root: root/a', '0');
  AppendSCase(LAggCases, 'am-nested-pass-hidden',
    'Af|pp|-|F|1 subtest(s) failed in root: root/f2', '0');
  AppendSCase(LAggCases, 'am-deep-chain-top',
    'A|B|f|F|1 subtest(s) failed in root: root/a', '0');
  AppendSCase(LAggCases, 'am-nested-and-flat-fail',
    'Af|f|-|F|2 subtest(s) failed in root: root/a, root/f2', '0');
  LMeta.TestTable('v8.39 subtest aggregate message', LAggCases, @RunAggMsgCase);

  { v8.39 表 B：RunWithResult 收集契约（pass 节点不收集、post-order、log 仅败留） }
  AppendSCase(LNodeCases, 'rc-root-first',
    'pf|-|-|root|0|1|1 subtest(s) failed in root: root/f2|0', '0');
  AppendSCase(LNodeCases, 'rc-pass-leaf-collected', 'pf|-|-|root/p1|1|0|-|0', '1');
  AppendSCase(LNodeCases, 'rc-fail-leaf-msg', 'pf|-|-|root/f2|2|1|boom|0', '0');
  AppendSCase(LNodeCases, 'rc-skip-leaf-reason', 'sp|-|-|root/s1|1|2|why|0', '1');
  AppendSCase(LNodeCases, 'rc-error-leaf-classmsg',
    'e|-|-|root/e1|1|3|Exception: kaboom|0', '0');
  AppendSCase(LNodeCases, 'rc-pass-nested-absent', 'Ap|pp|-|root/a|-|-|-|-', '1');
  AppendSCase(LNodeCases, 'rc-fail-nested-collapsed',
    'Ap|pf|-|root/a|3|1|1 subtest(s) failed in root/a: root/a/f2|0', '0');
  AppendSCase(LNodeCases, 'rc-post-order-leaf', 'Ap|pf|-|root/a/f2|2|1|boom|0', '0');
  AppendSCase(LNodeCases, 'rc-deep-mid-node',
    'A|B|f|root/a/b|2|1|1 subtest(s) failed in root/a/b: root/a/b/f1|0', '0');
  AppendSCase(LNodeCases, 'rc-deep-top-node',
    'A|B|f|root/a|3|1|1 subtest(s) failed in root/a: root/a/b|0', '0');
  AppendSCase(LNodeCases, 'rc-log-captured-on-fail',
    'l|-|-|root/l1|1|1|logfail|2', '0');
  AppendSCase(LNodeCases, 'rc-log-dropped-on-pass', 'm|-|-|root/m1|1|0|-|0', '1');
  AppendSCase(LNodeCases, 'rc-root-carries-last-log',
    'l|-|-|root|0|1|1 subtest(s) failed in root: root/l1|2', '0');
  LMeta.TestTable('v8.39 subtest result collection', LNodeCases, @RunNodeResultCase);

  { v8.39 表 C：suite 计数（subtest 内 pass/skip 不可见、fail 整条计 1） }
  AppendSCase(LCntCases, 'sc-sub-pass-invisible', 'pp|-|-|-|T|0|0|0', '1');
  AppendSCase(LCntCases, 'sc-sub-skip-invisible', 'sp|-|-|-|T|0|0|0', '1');
  AppendSCase(LCntCases, 'sc-two-leaf-fail-one', 'ff|-|-|-|F|0|1|0', '0');
  AppendSCase(LCntCases, 'sc-nested-fail-one', 'Ap|-|-|ff|F|0|1|0', '0');
  AppendSCase(LCntCases, 'sc-two-roots-one-fail', 'pf|pp|-|-|F|0|1|0', '0');
  AppendSCase(LCntCases, 'sc-two-roots-both-fail', 'f|f|-|-|F|0|2|0', '0');
  AppendSCase(LCntCases, 'sc-plain-counted', 'pp|-|y|-|T|1|0|0', '1');
  AppendSCase(LCntCases, 'sc-plain-plus-subfail', 'f|-|y|-|F|1|1|0', '0');
  AppendSCase(LCntCases, 'sc-empty-suite-sub', '-|-|-|-|T|0|0|0', '1');
  LMeta.TestTable('v8.39 subtest suite counters', LCntCases, @RunCountCase);

  { v8.39 表 D：env 隔离状态机（逆序恢复、empty vs missing、fail 后仍恢复） }
  AppendSCase(LEnvCases, 'env-set-on-missing', 'x|sa|-|aa|F|-', '1');
  AppendSCase(LEnvCases, 'env-set-on-empty', 'y|sa|-|aa|T|~', '1');
  AppendSCase(LEnvCases, 'env-set-on-orig', 'o|sa|-|aa|T|orig', '1');
  AppendSCase(LEnvCases, 'env-unset-on-orig', 'o|u|-|-|T|orig', '1');
  AppendSCase(LEnvCases, 'env-unset-on-missing', 'x|u|-|-|F|-', '1');
  AppendSCase(LEnvCases, 'env-double-set-restore-first', 'o|sa,sb|-|bb|T|orig', '1');
  AppendSCase(LEnvCases, 'env-set-then-unset', 'o|sa,u|-|-|T|orig', '1');
  AppendSCase(LEnvCases, 'env-unset-then-set', 'o|u,sb|-|bb|T|orig', '1');
  AppendSCase(LEnvCases, 'env-restore-after-fail', 'o|sa|F|aa|T|orig', '0');
  AppendSCase(LEnvCases, 'env-restore-after-fail-missing', 'x|sa|F|aa|F|-', '0');
  AppendSCase(LEnvCases, 'env-missing-double-set', 'x|sa,sb|-|bb|F|-', '1');
  AppendSCase(LEnvCases, 'env-set-empty-value', 'o|se|-|~|T|orig', '1');
  LMeta.TestTable('v8.39 subtest env isolation', LEnvCases, @RunEnvCase);

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
