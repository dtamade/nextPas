program test_process_deep;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.process,
  nextpas.core.process.base,
  nextpas.core.process.child,
  nextpas.core.process.command,
  nextpas.core.process.pipe;

var
  T: TTestRunner;

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
  (LStdin as TPipeWriter).Close;
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

procedure TestProcessErrorUsesFrameworkRootAndCategory;
var
  LGotRoot: Boolean;
  LGotSpecific: Boolean;
begin
  LGotRoot := False;
  LGotSpecific := False;
  try
    Command('/nonexistent_binary_xyz_deep_test').Output;
  except
    on E: EProcessError do
    begin
      LGotSpecific := True;
      Check(E.Category = ecNotFound, 'exec failure keeps not-found category');
      Check(E.ExitCode <> -1, 'exec failure keeps platform error code');
    end;
    on E: ENextPasError do
      LGotRoot := True;
  end;
  Check(LGotSpecific and not LGotRoot,
    'process error is a framework-root exception with specific catch priority');

  LGotSpecific := False;
  try
    Command('/nonexistent_secret-token_binary_xyz_deep_test').Output;
  except
    on E: EProcessError do
    begin
      LGotSpecific := True;
      Check(Pos('secret-token', E.Message) = 0,
        'exec failure message must not include sensitive command path data');
    end;
  end;
  Check(LGotSpecific, 'secret-marked nonexistent binary raises EProcessError');

  LGotRoot := False;
  try
    raise EProcessError.Create('unknown process failure');
  except
    on E: ENextPasError do
    begin
      LGotRoot := True;
      Check(E.Category = ecInternal, 'unknown process error uses internal category');
    end;
  end;
  Check(LGotRoot, 'default process error catches as ENextPasError');
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
  LCode: Integer;
begin
  LCode := Command('/bin/echo')
    .Args(['should', 'not', 'appear'])
    .Stdout(stNull)
    .Status;
  CheckEqual(Int64(0), Int64(LCode), 'stdout null exits 0');
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
  (LStdin as TPipeWriter).Close;
  LStdin := nil;
  LOut := LChild.WaitWithOutput;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'wwo exit 0');
  Check(Pos('waitwithoutput_test', LOut.StdOut) > 0, 'wwo stdout');
  Check(Pos('done', LOut.StdErr) > 0, 'wwo stderr');
end;

{ --- Main --- }

begin
  T := TTestRunner.Create('nextpas.core.process [deep]');
  T.Run('Run simple command', @TestRunSimpleCommand);
  T.Run('Exit codes', @TestExitCodes);
  T.Run('Stdin piping', @TestStdinPiping);
  T.Run('Stderr capture', @TestStderrCapture);
  T.Run('Environment variables', @TestEnvironmentVariables);
  T.Run('Working directory', @TestWorkingDirectory);
  T.Run('Process timeout', @TestProcessTimeout);
  T.Run('Non-existent command', @TestNonExistentCommand);
  T.Run('Process error framework root and category', @TestProcessErrorUsesFrameworkRootAndCategory);
  T.Run('Large output 100KB', @TestLargeOutput);
  T.Run('Multiple processes', @TestMultipleProcesses);
  T.Run('Spawn + Kill', @TestSpawnKill);
  T.Run('TryWait', @TestTryWait);
  T.Run('Stdin null', @TestStdinNull);
  T.Run('Stdout null', @TestStdoutNull);
  T.Run('Chdir fail', @TestChdirFail);
  T.Run('Command reuse', @TestCommandReuse);
  T.Run('Capture', @TestCapture);
  T.Run('RunIn', @TestRunIn);
  T.Run('Dual pipe large', @TestDualPipeLarge);
  T.Run('WaitWithOutput stdin', @TestWaitWithOutputStdin);
  T.Summary;
end.
