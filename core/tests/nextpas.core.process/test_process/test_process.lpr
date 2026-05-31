program test_process;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.process,
  nextpas.core.process.base,
  nextpas.core.process.child,
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

procedure TestRunEcho;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/echo', ['hello', 'world']);
  Check('Run echo — success', LOut.ExitCode = 0);
  Check('Run echo — stdout', Pos('hello world', LOut.StdOut) > 0);
  Check('Run echo — status exited', LOut.Status = psExited);
end;

procedure TestRunFalse;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/false', []);
  Check('Run false — non-zero exit', LOut.ExitCode <> 0);
  Check('Run false — status exited', LOut.Status = psExited);
end;

procedure TestRunStderr;
var LOut: TProcessOutput;
begin
  LOut := Run('/bin/ls', ['/nonexistent_xyz_path']);
  Check('Run ls bad — stderr not empty', Length(LOut.StdErr) > 0);
  Check('Run ls bad — non-zero exit', LOut.ExitCode <> 0);
end;

procedure TestCapture;
var LStr: string;
begin
  LStr := Capture('/bin/echo', ['captured']);
  Check('Capture — contains text', Pos('captured', LStr) > 0);
end;

procedure TestRunIn;
var LOut: TProcessOutput;
begin
  LOut := RunIn('/bin/pwd', [], '/tmp');
  Check('RunIn — workdir /tmp', Pos('/tmp', LOut.StdOut) > 0);
end;

procedure TestCommandBuilder;
var LOut: TProcessOutput;
begin
  LOut := Command('/bin/echo')
    .Args(['builder', 'test'])
    .Output;
  Check('Command builder — success', LOut.ExitCode = 0);
  Check('Command builder — stdout', Pos('builder test', LOut.StdOut) > 0);
end;

procedure TestCommandDir;
var LOut: TProcessOutput;
begin
  LOut := Command('/bin/pwd')
    .Dir('/tmp')
    .Output;
  Check('Command dir — /tmp', Pos('/tmp', LOut.StdOut) > 0);
end;

procedure TestCommandStatus;
var LCode: Integer;
begin
  LCode := Command('/bin/true').Status;
  Check('Command status true — 0', LCode = 0);
  LCode := Command('/bin/false').Status;
  Check('Command status false — non-zero', LCode <> 0);
end;

procedure TestSpawnAndWait;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/sleep').Arg('0.1').Spawn;
  Check('Spawn — pid > 0', LChild.Pid > 0);
  LOut := LChild.Wait;
  Check('Spawn wait — exited', LOut.Status = psExited);
  Check('Spawn wait — exit 0', LOut.ExitCode = 0);
end;

procedure TestSpawnTryWait;
var
  LChild: IChild;
  LOut: TProcessOutput;
  LDone: Boolean;
begin
  LChild := Command('/bin/sleep').Arg('0.05').Spawn;
  LDone := LChild.TryWait(LOut);
  Check('TryWait — not done immediately', not LDone);
  LOut := LChild.Wait;
  Check('TryWait then Wait — exited', LOut.Status = psExited);
end;

procedure TestSpawnKill;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := Command('/bin/sleep').Arg('10').Spawn;
  LChild.Kill;
  LOut := LChild.Wait;
  Check('Kill — signaled', LOut.Status = psSignaled);
end;

procedure TestSpawnStdinPipe;
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
  LData := 'piped input';
  LStdin.Write(LData[1], Length(LData));
  LStdin := nil;  // close stdin
  LOut := LChild.WaitWithOutput;
  Check('Stdin pipe — echoed back', Pos('piped input', LOut.StdOut) > 0);
end;

procedure TestSpawnStdoutReader;
var
  LChild: IChild;
  LReader: IReader;
  LBuf: array[0..255] of Byte;
  LRead: SizeUInt;
  LTotal: string;
begin
  LChild := Command('/bin/echo')
    .Args(['streaming', 'read'])
    .Stdout(stPiped)
    .Spawn;
  LReader := LChild.TakeStdout;
  LTotal := '';
  repeat
    LRead := LReader.Read(LBuf[0], 256);
    if LRead > 0 then
    begin
      SetLength(LTotal, Length(LTotal) + Integer(LRead));
      Move(LBuf[0], LTotal[Length(LTotal) - Integer(LRead) + 1], LRead);
    end;
  until LRead = 0;
  LChild.Wait;
  Check('Stdout reader — streaming', Pos('streaming read', LTotal) > 0);
end;

procedure TestCommandEnv;
var LOut: TProcessOutput;
begin
  LOut := Command('/usr/bin/env')
    .Env(['MY_TEST_VAR=hello_from_core'])
    .Stdout(stPiped)
    .Stderr(stPiped)
    .Spawn
    .WaitWithOutput;
  Check('Env — custom var visible', Pos('MY_TEST_VAR=hello_from_core', LOut.StdOut) > 0);
end;

procedure TestSpawnError;
var
  LOut: TProcessOutput;
begin
  LOut := Command('/nonexistent_binary_xyz').Output;
  Check('Spawn nonexistent — exit 127', LOut.ExitCode = 127);
end;

begin
  LPassed := 0;
  LFailed := 0;

  WriteLn('--- nextpas.core.process full test suite ---');
  WriteLn('');

  TestRunEcho;
  TestRunFalse;
  TestRunStderr;
  TestCapture;
  TestRunIn;
  TestCommandBuilder;
  TestCommandDir;
  TestCommandStatus;
  TestSpawnAndWait;
  TestSpawnTryWait;
  TestSpawnKill;
  TestSpawnStdinPipe;
  TestSpawnStdoutReader;
  TestCommandEnv;
  TestSpawnError;

  WriteLn('');
  WriteLn('--- ', LPassed, ' passed, ', LFailed, ' failed ---');
  if LFailed > 0 then
    Halt(1);
end.
