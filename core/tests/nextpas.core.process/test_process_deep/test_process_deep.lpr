program test_process_deep;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.async.cancellation,
  nextpas.core.process,
  nextpas.core.process.base,
  nextpas.core.process.child,
  nextpas.core.process.command,
  nextpas.core.process.pipe;

var
  T: TTestSuite;

{ --- Test 1: Run simple command — verify output --- }

procedure TestRunSimpleCommand;
var
  LOut: TProcessOutput;
begin
  LOut := Run('/bin/echo', ['hello', 'world']);
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'echo exit 0');
  Check(LOut.Status = psExited, 'echo status exited');
  Check(Pos('hello world', LOut.StdOut) > 0, 'echo stdout contains hello world');
end;

{ --- Test 2: Exit code (true -> 0, false -> 1) --- }

procedure TestExitCodes;
var
  LOut: TProcessOutput;
begin
  LOut := Run('/bin/true', []);
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'true exits 0');
  Check(LOut.Status = psExited, 'true status exited');

  LOut := Run('/bin/false', []);
  Check(LOut.ExitCode <> 0, 'false exits non-zero');
  Check(LOut.Status = psExited, 'false status exited');

  { Custom exit code via sh }
  LOut := Run('/bin/sh', ['-c', 'exit 42']);
  CheckEqual(Int64(42), Int64(LOut.ExitCode), 'exit 42');
end;

{ --- Test 3: Stdin piping --- }

procedure TestStdinPiping;
var
  LChild: IChild;
  LStdin: IWriter;
  LCloser: IWriteCloser;
  LOut: TProcessOutput;
  LData: string;
begin
  LChild := Command('/bin/cat')
    .Stdin(stPiped)
    .Stdout(stPiped)
    .Spawn;
  LStdin := LChild.TakeStdin;
  LData := 'piped_input_data_12345';
  LStdin.Write(LData[1], Length(LData));
  LCloser := LStdin as IWriteCloser;
  LCloser.Close;
  LCloser := nil;
  LStdin := nil;
  LOut := LChild.WaitWithOutput;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'cat exit 0');
  Check(Pos('piped_input_data_12345', LOut.StdOut) > 0, 'stdin echoed back');
end;

{ --- Test 4: Stderr capture --- }

procedure TestStderrCapture;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/sh')
    .Args(['-c', 'echo stdout_msg; echo stderr_msg >&2'])
    .Output;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'sh exit 0');
  Check(Pos('stdout_msg', LOut.StdOut) > 0, 'stdout captured');
  Check(Pos('stderr_msg', LOut.StdErr) > 0, 'stderr captured');
end;

{ --- Test 5: Environment variables --- }

procedure TestEnvironmentVariables;
var
  LOut: TProcessOutput;
begin
  { Replace env completely }
  LOut := Command('/usr/bin/env')
    .Env(['MY_VAR=hello_env', 'PATH=/bin:/usr/bin'])
    .Output;
  Check(Pos('MY_VAR=hello_env', LOut.StdOut) > 0, 'custom env var visible');

  { EnvAdd overlays on parent env }
  LOut := Command('/usr/bin/env')
    .EnvAdd('OVERLAY_KEY', 'overlay_val')
    .Output;
  Check(Pos('OVERLAY_KEY=overlay_val', LOut.StdOut) > 0, 'overlay var visible');
  Check(Pos('PATH=', LOut.StdOut) > 0, 'parent PATH inherited');
end;

{ --- Test 6: Working directory --- }

procedure TestWorkingDirectory;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/pwd')
    .Dir('/tmp')
    .Output;
  Check(Pos('/tmp', LOut.StdOut) > 0, 'cwd is /tmp');

  LOut := Command('/bin/pwd')
    .Dir('/')
    .Output;
  Check(Pos('/', LOut.StdOut) > 0, 'cwd is /');
end;

{ --- Test 7: Process timeout/kill --- }

procedure TestProcessTimeout;
var
  LOut: TProcessOutput;
  LStart: TInstant;
begin
  LStart := TInstant.Now;
  LOut := Command('/bin/sleep')
    .Arg('10')
    .Timeout(TDuration.FromMilliseconds(200))
    .Output;
  Check(LOut.Status = psSignaled, 'timeout kills process');
  Check(LStart.Elapsed.AsMilliseconds < 3000, 'did not wait 10s');
  Check(LStart.Elapsed.AsMilliseconds >= 100, 'waited at least 100ms');
end;

{ --- Test 8: Non-existent command --- }

procedure TestNonExistentCommand;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    Command('/nonexistent_binary_xyz_deep_test').Output;
  except
    on E: EProcessError do
      LGot := True;
  end;
  Check(LGot, 'nonexistent binary raises EProcessError');
end;

{ --- Test 9: Large output (100KB) --- }

procedure TestLargeOutput;
var
  LOut: TProcessOutput;
begin
  { Generate ~100KB of output using seq }
  LOut := Command('/bin/sh')
    .Args(['-c', 'seq 1 20000'])
    .Output;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'seq exit 0');
  Check(Length(LOut.StdOut) > 100000, 'output > 100KB');
  Check(Pos('1', LOut.StdOut) > 0, 'contains 1');
  Check(Pos('20000', LOut.StdOut) > 0, 'contains 20000');
end;

{ --- Test 10: Multiple processes --- }

procedure TestMultipleProcesses;
var
  LOut1, LOut2, LOut3: TProcessOutput;
begin
  LOut1 := Run('/bin/echo', ['proc1']);
  LOut2 := Run('/bin/echo', ['proc2']);
  LOut3 := Run('/bin/echo', ['proc3']);
  Check(Pos('proc1', LOut1.StdOut) > 0, 'proc1 output');
  Check(Pos('proc2', LOut2.StdOut) > 0, 'proc2 output');
  Check(Pos('proc3', LOut3.StdOut) > 0, 'proc3 output');
  CheckEqual(Int64(0), Int64(LOut1.ExitCode), 'proc1 exit 0');
  CheckEqual(Int64(0), Int64(LOut2.ExitCode), 'proc2 exit 0');
  CheckEqual(Int64(0), Int64(LOut3.ExitCode), 'proc3 exit 0');
end;

{ --- Test 11: Spawn + Kill --- }

procedure TestSpawnKill;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/sleep').Arg('60').Spawn;
  Check(LChild.Pid > 0, 'pid > 0');
  LChild.Kill;
  LOut := LChild.Wait;
  Check(LOut.Status = psSignaled, 'killed = signaled');
end;

{ --- Test 12: TryWait --- }

procedure TestTryWait;
var
  LChild: IChild;
  LOut: TProcessOutput;
  LDone: Boolean;
begin
  LChild := Command('/bin/sleep').Arg('0.05').Spawn;
  LDone := LChild.TryWait(LOut);
  Check(not LDone, 'not done immediately');
  LOut := LChild.Wait;
  Check(LOut.Status = psExited, 'eventually exits');
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'exit 0');
end;

{ --- Test 13: Stdin null --- }

procedure TestStdinNull;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/cat')
    .Stdin(stNull)
    .Output;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'cat stdin null exit 0');
  CheckEqual('', LOut.StdOut, 'cat stdin null no output');
end;

{ --- Test 14: Stdout null --- }

procedure TestStdoutNull;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/echo')
    .Args(['should', 'not', 'appear'])
    .Stdout(stNull)
    .Status;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'stdout null exits 0');
end;

{ --- Test 15: Chdir fail --- }

procedure TestChdirFail;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    Command('/bin/true').Dir('/nonexistent_dir_xyz_deep').Spawn;
  except
    on E: EProcessError do
      LGot := True;
  end;
  Check(LGot, 'chdir fail raises EProcessError');
end;

{ --- Test 16: Command reuse --- }

procedure TestCommandReuse;
var
  LCmd: ICommand;
  LOut1, LOut2: TProcessOutput;
begin
  LCmd := Command('/bin/echo').Args(['reuse_test']);
  LOut1 := LCmd.Output;
  LOut2 := LCmd.Output;
  Check(Pos('reuse_test', LOut1.StdOut) > 0, 'first run');
  Check(Pos('reuse_test', LOut2.StdOut) > 0, 'second run');
end;

{ --- Test 17: Capture convenience --- }

procedure TestCapture;
var
  LStr: string;
begin
  LStr := Capture('/bin/echo', ['capture_deep']);
  Check(Pos('capture_deep', LStr) > 0, 'capture returns stdout');
end;

{ --- Test 18: RunIn convenience --- }

procedure TestRunIn;
var
  LOut: TProcessOutput;
begin
  LOut := RunIn('/bin/pwd', [], '/tmp');
  Check(Pos('/tmp', LOut.StdOut) > 0, 'RunIn sets cwd');
end;

{ --- Test 19: Dual pipe (stdout + stderr) large --- }

procedure TestDualPipeLarge;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/sh')
    .Args(['-c', 'seq 1 5000; seq 1 1000 >&2'])
    .Output;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'dual pipe exit 0');
  Check(Length(LOut.StdOut) > 10000, 'stdout > 10KB');
  Check(Length(LOut.StdErr) > 1000, 'stderr > 1KB');
end;

{ --- Test 20: WaitWithOutput with stdin pipe --- }

procedure TestWaitWithOutputStdin;
var
  LChild: IChild;
  LStdin: IWriter;
  LCloser: IWriteCloser;
  LOut: TProcessOutput;
  LData: string;
begin
  LChild := Command('/bin/sh')
    .Args(['-c', 'cat; echo done >&2'])
    .Stdin(stPiped)
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn;
  LStdin := LChild.TakeStdin;
  LData := 'waitwithoutput_test';
  LStdin.Write(LData[1], Length(LData));
  LCloser := LStdin as IWriteCloser;
  LCloser.Close;
  LCloser := nil;
  LStdin := nil;
  LOut := LChild.WaitWithOutput;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'wwo exit 0');
  Check(Pos('waitwithoutput_test', LOut.StdOut) > 0, 'wwo stdout');
  Check(Pos('done', LOut.StdErr) > 0, 'wwo stderr');
end;

{ --- R22: CancelToken on plain Wait / Status (no pipes) --- }

procedure TestCancelTokenOnStatus;
var
  LTok: IAsyncCancellationToken;
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LTok := CreateCancellationToken;
  LChild := Command('/bin/sleep')
    .Arg('30')
    .CancelToken(LTok)
    .Spawn;
  LTok.Cancel;
  LOut := LChild.Wait;
  Check(LOut.Status <> psRunning, 'cancel Wait — not running');
  Check(LOut.Cancelled, 'cancel Wait — Cancelled flag');
  Check(not LOut.TimedOut, 'cancel Wait — not TimedOut');
  Check(not ProcessSucceeded(LOut), 'cancel Wait — not succeeded');
end;

procedure TestCancelTokenOnStatusBuilder;
var
  LTok: IAsyncCancellationToken;
  LOut: TProcessOutput;
begin
  LTok := CreateCancellationToken;
  { Status uses Wait (no capture pipes); must still honor CancelToken. }
  LTok.Cancel;
  try
    LOut := Command('/bin/sleep').Arg('30').CancelToken(LTok).Status;
    Check(False, 'cancel Status pre-spawn should raise');
  except
    on E: EProcessError do
      Check(Pos('cancel', E.Message) > 0, 'cancel Status pre-spawn message');
  end;
  LTok := CreateCancellationToken;
  { Mid-wait cancel is covered by Wait path above; Status after spawn: }
  LOut := Command('/bin/true').CancelToken(LTok).Status;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Status true still succeeds without cancel');
  Check(not LOut.Cancelled, 'Status true — not cancelled');
end;

procedure TestDoubleWaitReturnsCached;
var
  LChild: IChild;
  L1, L2: TProcessOutput;
begin
  LChild := Command('/bin/echo').Arg('once').Stdout(stPiped).Spawn;
  L1 := LChild.Wait;
  L2 := LChild.Wait;
  CheckEqual(Int64(0), Int64(L1.ExitCode), 'first Wait exit 0');
  CheckEqual(L1.ExitCode, L2.ExitCode, 'second Wait same exit');
  CheckEqual(L1.StdOut, L2.StdOut, 'second Wait same stdout');
  Check(not L2.TimedOut, 'second Wait not timed out');
end;

procedure TestMergeStderrMaxOutput;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/bin/sh')
    .Args(['-c', 'yes'])
    .MergeStderr
    .MaxOutput(64)
    .Output;
  Check(LOut.OutputLimited, 'Merge+MaxOutput — OutputLimited');
  Check(not LOut.TimedOut, 'Merge+MaxOutput — not TimedOut');
  Check(not ProcessSucceeded(LOut), 'Merge+MaxOutput — not succeeded');
end;

{ --- Main --- }

begin
  T := TTestSuite.Create('nextpas.core.process [deep]');
  T.Test('Run simple command', @TestRunSimpleCommand);
  T.Test('Exit codes', @TestExitCodes);
  T.Test('Stdin piping', @TestStdinPiping);
  T.Test('Stderr capture', @TestStderrCapture);
  T.Test('Environment variables', @TestEnvironmentVariables);
  T.Test('Working directory', @TestWorkingDirectory);
  T.Test('Process timeout', @TestProcessTimeout);
  T.Test('Non-existent command', @TestNonExistentCommand);
  T.Test('Large output 100KB', @TestLargeOutput);
  T.Test('Multiple processes', @TestMultipleProcesses);
  T.Test('Spawn + Kill', @TestSpawnKill);
  T.Test('TryWait', @TestTryWait);
  T.Test('Stdin null', @TestStdinNull);
  T.Test('Stdout null', @TestStdoutNull);
  T.Test('Chdir fail', @TestChdirFail);
  T.Test('Command reuse', @TestCommandReuse);
  T.Test('Capture', @TestCapture);
  T.Test('RunIn', @TestRunIn);
  T.Test('Dual pipe large', @TestDualPipeLarge);
  T.Test('WaitWithOutput stdin', @TestWaitWithOutputStdin);
  T.Test('R22 CancelToken on Wait', @TestCancelTokenOnStatus);
  T.Test('R22 CancelToken Status edges', @TestCancelTokenOnStatusBuilder);
  T.Test('R22 Double Wait cached', @TestDoubleWaitReturnsCached);
  T.Test('R22 MergeStderr MaxOutput', @TestMergeStderrMaxOutput);
  if not T.Run then Halt(1);
end.
