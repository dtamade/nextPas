program test_platform_process;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.process.base,
  nextpas.core.platform.process,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestSpawnTrue;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..1] of PAnsiChar;
begin
  LArgv[0] := '/bin/true';
  LArgv[1] := nil;
  Check(platform_process_spawn('/bin/true', @LArgv[0], nil, P) = 0, 'spawn /bin/true');
  Check(P.Pid > 0, 'pid > 0');
  Check(platform_process_wait(P, R) = 0, 'wait');
  Check(R.Status = psExited, 'exited');
  Check(R.ExitCode = 0, 'exit code 0');
end;

procedure TestSpawnFalse;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..1] of PAnsiChar;
begin
  LArgv[0] := '/bin/false';
  LArgv[1] := nil;
  Check(platform_process_spawn('/bin/false', @LArgv[0], nil, P) = 0, 'spawn /bin/false');
  Check(platform_process_wait(P, R) = 0, 'wait');
  Check(R.Status = psExited, 'exited');
  Check(R.ExitCode = 1, 'exit code 1');
end;

procedure TestPid;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..1] of PAnsiChar;
begin
  LArgv[0] := '/bin/true';
  LArgv[1] := nil;
  platform_process_spawn('/bin/true', @LArgv[0], nil, P);
  Check(platform_process_pid(P) = P.Pid, 'pid accessor');
  platform_process_wait(P, R);
end;

procedure TestKill;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..2] of PAnsiChar;
begin
  LArgv[0] := '/bin/sleep';
  LArgv[1] := '60';
  LArgv[2] := nil;
  Check(platform_process_spawn('/bin/sleep', @LArgv[0], nil, P) = 0, 'spawn sleep');
  Check(platform_process_kill(P) = 0, 'kill');
  Check(platform_process_wait(P, R) = 0, 'wait after kill');
  Check(R.Status = psSignaled, 'signaled');
  Check(R.ExitCode = 9, 'signal 9 (SIGKILL)');
end;

procedure TestTryWait;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..2] of PAnsiChar;
begin
  LArgv[0] := '/bin/sleep';
  LArgv[1] := '60';
  LArgv[2] := nil;
  Check(platform_process_spawn('/bin/sleep', @LArgv[0], nil, P) = 0, 'spawn');
  Check(platform_process_try_wait(P, R) = 0, 'try_wait');
  Check(R.Status = psRunning, 'still running');
  platform_process_kill(P);
  platform_process_wait(P, R);
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.process');
  T.Run('spawn /bin/true', @TestSpawnTrue);
  T.Run('spawn /bin/false exit 1', @TestSpawnFalse);
  T.Run('pid accessor', @TestPid);
  T.Run('kill', @TestKill);
  T.Run('try_wait non-blocking', @TestTryWait);
  T.Summary;
end.
