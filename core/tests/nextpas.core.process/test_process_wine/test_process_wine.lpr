program test_process_wine;

{ L2 process Windows evidence under Wine.
  truth=wine-runtime-smoke — NOT real Windows host runtime. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.process,
  nextpas.core.process.base,
  nextpas.core.process.command
  ;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

procedure TestCmdEcho;
var
  LOut: TProcessOutput;
begin
  LOut := Run('cmd.exe', ['/c', 'echo hello_l2_wine']);
  Check(ProcessSucceeded(LOut) or (LOut.ExitCode = 0), 'cmd exit ok');
  Check(Pos('hello_l2_wine', LOut.StdOut) > 0, 'stdout contains echo text');
end;

procedure TestLookPathCmd;
var
  LPath: string;
begin
  LPath := LookPath('cmd.exe');
  Check(LPath <> '', 'LookPath cmd.exe non-empty');
  Check(TryLookPath('cmd.exe', LPath), 'TryLookPath cmd.exe');
  Check(not TryLookPath('Z:\no\such\missing_bin_xyz.exe', LPath),
    'TryLookPath abs missing false');
end;

procedure TestTimeout;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('cmd.exe')
    .Args(['/c', 'ping -n 10 127.0.0.1 >nul'])
    .Timeout(TDuration.FromMilliseconds(300))
    .Output;
  Check(LOut.TimedOut or (not ProcessSucceeded(LOut)), 'timeout or non-success');
end;

procedure TestMaxOutput;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('cmd.exe')
    .Args(['/c', 'for /L %i in (1,1,500) do @echo yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'])
    .MaxOutput(128)
    .Output;
  Check(LOut.OutputLimited or (Length(LOut.StdOut) <= 128),
    'MaxOutput limited or short');
  Check(not ProcessSucceeded(LOut) or LOut.OutputLimited,
    'success only if not limited path');
end;

{$ELSE}

procedure TestSkipHost;
begin
  Check(True, 'host is not Windows; wine suite is cross-target only');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('process L2 wine-runtime-smoke');
{$IFDEF NEXTPAS_WINDOWS}
  T.Test('cmd echo', @TestCmdEcho);
  T.Test('LookPath cmd', @TestLookPathCmd);
  T.Test('timeout', @TestTimeout);
  T.Test('MaxOutput', @TestMaxOutput);
{$ELSE}
  T.Test('skip non-windows host', @TestSkipHost);
{$ENDIF}
  if not T.Run then
    Halt(1);
end.
