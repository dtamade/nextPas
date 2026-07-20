program test_process_wine;

{ L2 process Windows evidence under Wine.
  truth=wine-runtime-smoke — NOT real Windows host runtime. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.process,
  nextpas.core.process.base,
  nextpas.core.process.command,
  nextpas.core.process.child
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

procedure TestCaptureEcho;
var
  S: string;
begin
  S := Capture('cmd.exe', ['/c', 'echo capture_wine_r34']);
  Check(Pos('capture_wine_r34', S) > 0, 'Capture stdout');
end;

procedure TestStatusExit0;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('cmd.exe')
    .Args(['/c', 'exit 0'])
    .Status;
  CheckEqual(Int64(0), Int64(LOut.ExitCode), 'Status exit 0');
  Check(ProcessSucceeded(LOut) or (LOut.ExitCode = 0), 'Status success path');
  Check(LOut.StdOut = '', 'Status no stdout capture');
end;


procedure TestWaitKill;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  { SIGTERM unsupported on Windows; Kill uses TerminateProcess. }
  LChild := TCommand.New('cmd.exe')
    .Args(['/c', 'ping -n 20 127.0.0.1 >nul'])
    .Spawn;
  LChild.Kill;
  LOut := LChild.Wait;
  Check(LOut.Status <> psRunning, 'Kill terminated');
end;

procedure TestStatusExit1;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New('cmd.exe')
    .Args(['/c', 'exit 1'])
    .Status;
  Check(LOut.ExitCode <> 0, 'Status non-zero');
  Check(not ProcessSucceeded(LOut), 'Status not succeeded');
end;

{ M2-W2: Job Object path for NewProcessGroup + KillTree. }
procedure TestNewProcessGroupKillTree;
var
  LChild: IChild;
  LOut: TProcessOutput;
begin
  LChild := TCommand.New('cmd.exe')
    .Args(['/c', 'ping -n 30 127.0.0.1 >nul'])
    .NewProcessGroup
    .Spawn;
  Check(LChild.ProcessGroupId = LChild.Pid, 'ProcessGroupId equals Pid on Win job');
  LChild.KillTree;
  LOut := LChild.Wait;
  Check(LOut.Status <> psRunning, 'KillTree terminated job');
end;

{ M2-W3: fail-closed matrix for ExtraFd / Credential. }
procedure TestExtraFdUnsupported;
var
  Raised: Boolean;
  Msg: string;
begin
  Raised := False;
  Msg := '';
  try
    TCommand.New('cmd.exe').Args(['/c', 'echo x']).ExtraFd(0).Spawn;
  except
    on E: EProcessError do
    begin
      Raised := True;
      Msg := E.Message;
    end;
  end;
  Check(Raised, 'ExtraFd raises on Windows');
  Check((Pos('unsupported', Msg) > 0) or (Pos('Unsupported', Msg) > 0) or
    (Pos('ExtraFd', Msg) > 0), 'ExtraFd message clear: ' + Msg);
end;

procedure TestCredentialUnsupported;
var
  Raised: Boolean;
  Msg: string;
begin
  Raised := False;
  Msg := '';
  try
    TCommand.New('cmd.exe').Args(['/c', 'echo x']).Credential(0, 0).Spawn;
  except
    on E: EProcessError do
    begin
      Raised := True;
      Msg := E.Message;
    end;
  end;
  Check(Raised, 'Credential raises on Windows');
  Check((Pos('unsupported', Msg) > 0) or (Pos('Unsupported', Msg) > 0) or
    (Pos('Credential', Msg) > 0), 'Credential message clear: ' + Msg);
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
  T.Test('Capture echo', @TestCaptureEcho);
  T.Test('LookPath cmd', @TestLookPathCmd);
  T.Test('timeout', @TestTimeout);
  T.Test('MaxOutput', @TestMaxOutput);
  T.Test('Status exit 0', @TestStatusExit0);
  T.Test('Status exit 1', @TestStatusExit1);
  T.Test('Kill', @TestWaitKill);
  T.Test('NewProcessGroup KillTree', @TestNewProcessGroupKillTree);
  T.Test('ExtraFd unsupported', @TestExtraFdUnsupported);
  T.Test('Credential unsupported', @TestCredentialUnsupported);
{$ELSE}
  T.Test('skip non-windows host', @TestSkipHost);
{$ENDIF}
  if not T.Run then
    Halt(1);
end.
