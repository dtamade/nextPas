program test_process_command;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.process,
  nextpas.core.time.base,
  nextpas.core.process.base,
  nextpas.core.process.child,
  nextpas.core.process.pipe,
  nextpas.core.process.command,
  nextpas.core.io.intf;

var
  T: TTestSuite;

{ S4-1: Basic spawn + wait — /bin/true returns exit code 0 }
procedure TestBasicSpawnWait;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := TCommand.New('/bin/true').Spawn;
  LOut := LChild.Wait;
  Check(LOut.Status = psExited, 'Basic spawn wait — exited');
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Basic spawn wait — exit code 0');
end;

{ S4-2: Non-zero exit code — /bin/false returns exit code 1 }
procedure TestNonZeroExitCode;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := TCommand.New('/bin/false').Spawn;
  LOut := LChild.Wait;
  Check(LOut.Status = psExited, 'Non-zero exit code — exited');
  CheckEqual(Int64(1), Int64(LOut.ExitCode), 'Non-zero exit code — exit code 1');
end;

{ S4-3: Argument passing — /bin/echo hello world captures stdout }
procedure TestArgPassing;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo')
    .Args(['hello', 'world'])
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn
    .WaitWithOutput;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Arg passing — exit 0');
  Check(Pos('hello world', LOut.StdOut) > 0,
    'Arg passing — stdout contains hello world');
end;

{ S4-4: Piped stdout — Spawn + WaitWithOutput captures output }
procedure TestPipedStdout;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo')
    .Arg('piped-test')
    .Stdout(stPiped)
    .Spawn
    .WaitWithOutput;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Piped stdout — exit 0');
  Check(Pos('piped-test', LOut.StdOut) > 0, 'Piped stdout — captures output');
end;

{ S4-5: Piped stderr — command writes to stderr, captured }
procedure TestPipedStderr;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/sh')
    .Args(['-c', 'echo error-msg >&2'])
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn
    .WaitWithOutput;
  Check(Pos('error-msg', LOut.StdErr) > 0, 'Piped stderr — captures stderr');
end;

{ S4-6: Working directory — pwd shows /tmp }
procedure TestWorkingDirectory;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/pwd')
    .Dir('/tmp')
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn
    .WaitWithOutput;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Working directory — exit 0');
  Check(Pos('/tmp', LOut.StdOut) > 0, 'Working directory — output is /tmp');
end;

{ S4-7: Custom environment variable }
procedure TestCustomEnvVar;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/sh')
    .Args(['-c', 'printf $NEXTPAS_TEST_VAR'])
    .Env(['PATH=/bin:/usr/bin', 'NEXTPAS_TEST_VAR=hello_from_env'])
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn
    .WaitWithOutput;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Custom env var — exit 0');
  Check(Pos('hello_from_env', LOut.StdOut) > 0,
    'Custom env var — value visible in child');
end;

{ S4-8: Timeout + kill — process killed after timeout }
procedure TestTimeoutKill;
var
  LOut: TProcessOutput;
  LStart: TInstant;
begin
  LStart := TInstant.Now;
  LOut := TCommand.New('/bin/sleep')
    .Arg('60')
    .Timeout(TDuration.FromMilliseconds(200))
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn
    .WaitWithOutput;
  Check(LOut.Status = psSignaled, 'Timeout kill — signaled');
  Check(LStart.Elapsed.AsMilliseconds < 2000, 'Timeout kill — elapsed < 2s');
end;

{ S4-9: Send signal to running process }
procedure TestSendSignal;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := TCommand.New('/bin/sleep')
    .Arg('60')
    .Spawn;
  Check(LChild.Pid > 0, 'Send signal — pid > 0');
  LChild.Kill;
  LOut := LChild.Wait;
  Check(LOut.Status = psSignaled, 'Send signal — signaled');
end;

{ S4-10: stdin redirection via pipe }
procedure TestStdinRedirection;
var
  LChild: IChild;
  LStdin: IWriter;
  LOut: TProcessOutput;
  LData: string;
begin
  LChild := TCommand.New('/bin/cat')
    .Stdin(stPiped)
    .Stdout(stPiped)
    .Spawn;
  LStdin := LChild.TakeStdin;
  LData := 'stdin-data-test';
  LStdin.Write(LData[1], Length(LData));
  LStdin := nil;  { close stdin to signal EOF }
  LOut := LChild.WaitWithOutput;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Stdin redirection — exit 0');
  Check(Pos('stdin-data-test', LOut.StdOut) > 0,
    'Stdin redirection — echoed back');
end;

{ S4-11: Exit code 128 + signum — SIGKILL => 137 }
procedure TestExitCode128Signum;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := TCommand.New('/bin/sleep')
    .Arg('60')
    .Spawn;
  LChild.Kill;
  LOut := LChild.Wait;
  Check(LOut.Status = psSignaled, 'Exit code 128+signum — signaled');
  CheckEqual(Int64(137), Int64(LOut.ExitCode),
    'Exit code 128+signum — exit code = 137');
end;

{ S4-12: Non-existent command raises EProcessError }
procedure TestNonExistentCommand;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TCommand.New('/nonexistent_binary_xyz_456').Spawn;
  except
    on E: EProcessError do
      LRaised := True;
  end;
  Check(LRaised, 'Non-existent command — raises EProcessError');
end;

{ S4-13: Empty argument list }
procedure TestEmptyArgs;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo')
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn
    .WaitWithOutput;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Empty args — exit 0');
end;

{ S4-14: Multi-line output — all lines captured }
procedure TestMultilineOutput;
var
  LOut: TProcessOutput;
  LLineCount: Integer;
  I: Integer;
begin
  LOut := TCommand.New('/bin/sh')
    .Args(['-c', 'printf "line1\nline2\nline3\n"'])
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn
    .WaitWithOutput;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Multi-line output — exit 0');
  Check(Pos('line1', LOut.StdOut) > 0, 'Multi-line output — line1 present');
  Check(Pos('line2', LOut.StdOut) > 0, 'Multi-line output — line2 present');
  Check(Pos('line3', LOut.StdOut) > 0, 'Multi-line output — line3 present');
  LLineCount := 0;
  for I := 1 to Length(LOut.StdOut) do
    if LOut.StdOut[I] = #10 then
      Inc(LLineCount);
  CheckEqual(Int64(3), Int64(LLineCount), 'Multi-line output — 3 lines');
end;

{ S4-15: Process state query — TryWait / status }
procedure TestProcessStateQuery;
var
  LChild: IChild;
  LOut: TProcessOutput;
  LDone: Boolean;
begin
  LChild := TCommand.New('/bin/sleep')
    .Arg('0.2')
    .Spawn;
  LDone := LChild.TryWait(LOut);
  Check(not LDone, 'State query — TryWait not done immediately');
  LOut := LChild.Wait;
  Check(LOut.Status = psExited, 'State query — Wait returns exited');
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'State query — exit code 0');
  LDone := LChild.TryWait(LOut);
  Check(LDone, 'State query — TryWait done after Wait');
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'State query — TryWait preserves exit code');
end;

{ Additional: Output convenience method }
procedure TestOutputConvenience;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo')
    .Args(['convenience'])
    .Output;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Output convenience — exit 0');
  Check(Pos('convenience', LOut.StdOut) > 0,
    'Output convenience — captures stdout');
  Check((LOut.StdOut <> '') or (LOut.StdErr <> ''),
    'Output convenience — stdout and stderr both piped');
end;

{ Additional: Status convenience method }
procedure TestStatusConvenience;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/true').Status;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Status convenience — true returns 0');
  Check(ProcessSucceeded(LOut), 'Status convenience — true ProcessSucceeded');
  LOut := TCommand.New('/bin/false').Status;
  Check(LOut.ExitCode <> 0, 'Status convenience — false returns non-zero');
end;

{ Additional: EnvAdd overlay }
procedure TestEnvAddOverlay;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/usr/bin/env')
    .EnvAdd('NEXTPAS_ADD_KEY', 'add_value')
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn
    .WaitWithOutput;
  Check(Pos('NEXTPAS_ADD_KEY=add_value', LOut.StdOut) > 0,
    'EnvAdd overlay — custom var visible');
  Check(Pos('PATH=', LOut.StdOut) > 0, 'EnvAdd overlay — PATH inherited');
end;

{ Additional: WaitWithOutput dual pipe }
procedure TestDualPipeWait;
var
  LChild: IChild;
  LStdin: IWriter;
  LCloser: IWriteCloser;
  LOut: TProcessOutput;
  LData: string;
begin
  LChild := TCommand.New('/bin/sh')
    .Args(['-c', 'cat; echo err-msg >&2'])
    .Stdin(stPiped)
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn;
  LStdin := LChild.TakeStdin;
  LData := 'dual-pipe-data';
  LStdin.Write(LData[1], Length(LData));
  LCloser := LStdin as IWriteCloser;
  LCloser.Close;
  LCloser := nil;
  LStdin := nil;
  LOut := LChild.WaitWithOutput;
  Check(Pos('dual-pipe-data', LOut.StdOut) > 0, 'Dual pipe wait — stdout');
  Check(Pos('err-msg', LOut.StdErr) > 0, 'Dual pipe wait — stderr');
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Dual pipe wait — exit 0');
end;

{ Additional: Null stdin }
procedure TestNullStdin;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/cat')
    .Stdin(stNull)
    .Stdout(stPiped)
    .Output;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Null stdin — cat gets EOF immediately');
  CheckEqual('', LOut.StdOut, 'Null stdin — no output');
end;

{ Additional: Reusable command builder }
procedure TestReusableCommand;
var
  LCmd: ICommand;
  LOut1, LOut2: TProcessOutput;
begin
  LCmd := TCommand.New('/bin/echo').Args(['reusable']);
  LOut1 := LCmd.Output;
  LOut2 := LCmd.Output;
  Check(Pos('reusable', LOut1.StdOut) > 0, 'Reusable command — first run');
  Check(Pos('reusable', LOut2.StdOut) > 0, 'Reusable command — second run');
end;

begin
  T := TTestSuite.Create('nextpas.core.process [command]');
  T.Test('Basic spawn wait', @TestBasicSpawnWait);
  T.Test('Non-zero exit code', @TestNonZeroExitCode);
  T.Test('Arg passing', @TestArgPassing);
  T.Test('Piped stdout', @TestPipedStdout);
  T.Test('Piped stderr', @TestPipedStderr);
  T.Test('Working directory', @TestWorkingDirectory);
  T.Test('Custom env var', @TestCustomEnvVar);
  T.Test('Timeout kill', @TestTimeoutKill);
  T.Test('Send signal', @TestSendSignal);
  T.Test('Stdin redirection', @TestStdinRedirection);
  T.Test('Exit code 128+signum', @TestExitCode128Signum);
  T.Test('Non-existent command', @TestNonExistentCommand);
  T.Test('Empty args', @TestEmptyArgs);
  T.Test('Multi-line output', @TestMultilineOutput);
  T.Test('Process state query', @TestProcessStateQuery);
  T.Test('Output convenience', @TestOutputConvenience);
  T.Test('Status convenience', @TestStatusConvenience);
  T.Test('EnvAdd overlay', @TestEnvAddOverlay);
  T.Test('Dual pipe wait', @TestDualPipeWait);
  T.Test('Null stdin', @TestNullStdin);
  T.Test('Reusable command', @TestReusableCommand);
  if not T.Run then
    Halt(1);
end.
