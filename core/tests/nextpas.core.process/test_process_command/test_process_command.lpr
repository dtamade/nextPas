program test_process_command;

{$I nextpas.core.settings.inc}

uses
  SysUtils, Classes,
  nextpas.core.process,
  nextpas.core.time.base,
  nextpas.core.process.base,
  nextpas.core.process.child,
  nextpas.core.process.pipe,
  nextpas.core.process.command,
  nextpas.core.io.intf;

var
  LPassed, LFailed: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  PASS: ', AName);
    Inc(LPassed);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Inc(LFailed);
  end;
end;

{ S4-1: Basic spawn + wait — /bin/true returns exit code 0 }
procedure TestBasicSpawnWait;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := TCommand.New('/bin/true').Spawn;
  LOut := LChild.Wait;
  Check('Basic spawn wait — exited', LOut.Status = psExited);
  Check('Basic spawn wait — exit code 0', LOut.ExitCode = 0);
end;

{ S4-2: Non-zero exit code — /bin/false returns exit code 1 }
procedure TestNonZeroExitCode;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := TCommand.New('/bin/false').Spawn;
  LOut := LChild.Wait;
  Check('Non-zero exit code — exited', LOut.Status = psExited);
  Check('Non-zero exit code — exit code 1', LOut.ExitCode = 1);
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
  Check('Arg passing — exit 0', LOut.ExitCode = 0);
  Check('Arg passing — stdout contains hello world',
    Pos('hello world', LOut.StdOut) > 0);
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
  Check('Piped stdout — exit 0', LOut.ExitCode = 0);
  Check('Piped stdout — captures output',
    Pos('piped-test', LOut.StdOut) > 0);
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
  Check('Piped stderr — captures stderr',
    Pos('error-msg', LOut.StdErr) > 0);
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
  Check('Working directory — exit 0', LOut.ExitCode = 0);
  Check('Working directory — output is /tmp',
    Pos('/tmp', LOut.StdOut) > 0);
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
  Check('Custom env var — exit 0', LOut.ExitCode = 0);
  Check('Custom env var — value visible in child',
    Pos('hello_from_env', LOut.StdOut) > 0);
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
  Check('Timeout kill — signaled', LOut.Status = psSignaled);
  Check('Timeout kill — elapsed < 2s', LStart.Elapsed.AsMilliseconds < 2000);
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
  Check('Send signal — pid > 0', LChild.Pid > 0);
  LChild.Kill;
  LOut := LChild.Wait;
  Check('Send signal — signaled', LOut.Status = psSignaled);
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
  Check('Stdin redirection — exit 0', LOut.ExitCode = 0);
  Check('Stdin redirection — echoed back',
    Pos('stdin-data-test', LOut.StdOut) > 0);
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
  Check('Exit code 128+signum — signaled', LOut.Status = psSignaled);
  Check('Exit code 128+signum — exit code = 137', LOut.ExitCode = 137);
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
  Check('Non-existent command — raises EProcessError', LRaised);
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
  Check('Empty args — exit 0', LOut.ExitCode = 0);
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
  Check('Multi-line output — exit 0', LOut.ExitCode = 0);
  Check('Multi-line output — line1 present', Pos('line1', LOut.StdOut) > 0);
  Check('Multi-line output — line2 present', Pos('line2', LOut.StdOut) > 0);
  Check('Multi-line output — line3 present', Pos('line3', LOut.StdOut) > 0);
  { Count newlines }
  LLineCount := 0;
  for I := 1 to Length(LOut.StdOut) do
    if LOut.StdOut[I] = #10 then
      Inc(LLineCount);
  Check('Multi-line output — 3 lines', LLineCount = 3);
end;

{ S4-15: Process state query — TryWait / status }
procedure TestProcessStateQuery;
var
  LChild: IChild;
  LOut: TProcessOutput;
  LDone: Boolean;
begin
  { Running process — TryWait should return False }
  LChild := TCommand.New('/bin/sleep')
    .Arg('0.2')
    .Spawn;
  LDone := LChild.TryWait(LOut);
  Check('State query — TryWait not done immediately', not LDone);
  { Wait for it to finish }
  LOut := LChild.Wait;
  Check('State query — Wait returns exited', LOut.Status = psExited);
  Check('State query — exit code 0', LOut.ExitCode = 0);
  { After Wait, TryWait should return True }
  LDone := LChild.TryWait(LOut);
  Check('State query — TryWait done after Wait', LDone);
  Check('State query — TryWait preserves exit code', LOut.ExitCode = 0);
end;

{ Additional: Output convenience method }
procedure TestOutputConvenience;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('/bin/echo')
    .Args(['convenience'])
    .Output;
  Check('Output convenience — exit 0', LOut.ExitCode = 0);
  Check('Output convenience — captures stdout',
    Pos('convenience', LOut.StdOut) > 0);
  Check('Output convenience — stdout and stderr both piped',
    (LOut.StdOut <> '') or (LOut.StdErr <> ''));
end;

{ Additional: Status convenience method }
procedure TestStatusConvenience;
var
  LCode: Integer;
begin
  LCode := TCommand.New('/bin/true').Status;
  Check('Status convenience — true returns 0', LCode = 0);
  LCode := TCommand.New('/bin/false').Status;
  Check('Status convenience — false returns non-zero', LCode <> 0);
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
  Check('EnvAdd overlay — custom var visible',
    Pos('NEXTPAS_ADD_KEY=add_value', LOut.StdOut) > 0);
  Check('EnvAdd overlay — PATH inherited',
    Pos('PATH=', LOut.StdOut) > 0);
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
  Check('Dual pipe wait — stdout', Pos('dual-pipe-data', LOut.StdOut) > 0);
  Check('Dual pipe wait — stderr', Pos('err-msg', LOut.StdErr) > 0);
  Check('Dual pipe wait — exit 0', LOut.ExitCode = 0);
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
  Check('Null stdin — cat gets EOF immediately', LOut.ExitCode = 0);
  Check('Null stdin — no output', LOut.StdOut = '');
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
  Check('Reusable command — first run', Pos('reusable', LOut1.StdOut) > 0);
  Check('Reusable command — second run', Pos('reusable', LOut2.StdOut) > 0);
end;

begin
  LPassed := 0;
  LFailed := 0;

  WriteLn('--- nextpas.core.process TCommand/IChild end-to-end tests ---');
  WriteLn('');

  TestBasicSpawnWait;
  TestNonZeroExitCode;
  TestArgPassing;
  TestPipedStdout;
  TestPipedStderr;
  TestWorkingDirectory;
  TestCustomEnvVar;
  TestTimeoutKill;
  TestSendSignal;
  TestStdinRedirection;
  TestExitCode128Signum;
  TestNonExistentCommand;
  TestEmptyArgs;
  TestMultilineOutput;
  TestProcessStateQuery;
  TestOutputConvenience;
  TestStatusConvenience;
  TestEnvAddOverlay;
  TestDualPipeWait;
  TestNullStdin;
  TestReusableCommand;

  WriteLn('');
  WriteLn('--- ', LPassed, ' passed, ', LFailed, ' failed ---');
  if LFailed > 0 then
    Halt(1);
end.
