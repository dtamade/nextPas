program test_platform_process;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.process.base,
  nextpas.core.platform.process,
  nextpas.core.platform.posix.ffi,
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

procedure TestSpawnNonExistent;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..1] of PAnsiChar;
  LRet: Int32;
begin
  LArgv[0] := '/nonexistent_binary_xyz';
  LArgv[1] := nil;
  LRet := platform_process_spawn('/nonexistent_binary_xyz', @LArgv[0], nil, P);
  if LRet = 0 then
  begin
    platform_process_wait(P, R);
    Check(R.ExitCode <> 0, 'non-existent exits with error');
  end
  else
    Check(LRet <> 0, 'spawn non-existent returns error');
end;

procedure TestSpawnWithArgs;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
begin
  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'exit 42';
  LArgv[3] := nil;
  Check(platform_process_spawn('/bin/sh', @LArgv[0], nil, P) = 0, 'spawn sh');
  Check(platform_process_wait(P, R) = 0, 'wait');
  Check(R.Status = psExited, 'exited');
  Check(R.ExitCode = 42, 'exit code 42');
end;

procedure TestSpawnPipedStdout;
var
  P: TPlatformProcess;
  Pipes: TPlatformProcessPipes;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..63] of AnsiChar;
  LRead: PtrInt;
begin
  LArgv[0] := '/bin/echo';
  LArgv[1] := 'hello';
  LArgv[2] := nil;
  Check(platform_process_spawn_piped('/bin/echo', @LArgv[0], nil, P, Pipes) = 0, 'spawn piped');
  Check(Pipes.StdoutRead >= 0, 'stdout pipe valid');
  nextpas.core.platform.posix.ffi.close(Pipes.StdinWrite);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := nextpas.core.platform.posix.ffi.read(Pipes.StdoutRead, @LBuf[0], 64);
  Check(LRead >= 5, 'read >= 5 bytes');
  Check(LBuf[0] = 'h', 'stdout[0] = h');
  nextpas.core.platform.posix.ffi.close(Pipes.StdoutRead);
  nextpas.core.platform.posix.ffi.close(Pipes.StderrRead);
  platform_process_wait(P, R);
  Check(R.ExitCode = 0, 'exit 0');
end;

procedure TestSpawnPipedStderr;
var
  P: TPlatformProcess;
  Pipes: TPlatformProcessPipes;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..255] of AnsiChar;
  LRead: PtrInt;
begin
  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'echo errmsg >&2; exit 1';
  LArgv[3] := nil;
  Check(platform_process_spawn_piped('/bin/sh', @LArgv[0], nil, P, Pipes) = 0, 'spawn');
  nextpas.core.platform.posix.ffi.close(Pipes.StdinWrite);
  nextpas.core.platform.posix.ffi.close(Pipes.StdoutRead);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := nextpas.core.platform.posix.ffi.read(Pipes.StderrRead, @LBuf[0], 256);
  Check(LRead > 0, 'stderr has output');
  Check(LBuf[0] = 'e', 'stderr[0] = e');
  nextpas.core.platform.posix.ffi.close(Pipes.StderrRead);
  platform_process_wait(P, R);
  Check(R.ExitCode = 1, 'exit 1');
end;

procedure TestSpawnPipedStdin;
var
  P: TPlatformProcess;
  Pipes: TPlatformProcessPipes;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..63] of AnsiChar;
  LRead: PtrInt;
begin
  LArgv[0] := '/bin/cat';
  LArgv[1] := nil;
  Check(platform_process_spawn_piped('/bin/cat', @LArgv[0], nil, P, Pipes) = 0, 'spawn cat');
  nextpas.core.platform.posix.ffi.write(Pipes.StdinWrite, PAnsiChar('ping'), 4);
  nextpas.core.platform.posix.ffi.close(Pipes.StdinWrite);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := nextpas.core.platform.posix.ffi.read(Pipes.StdoutRead, @LBuf[0], 64);
  Check(LRead = 4, 'read 4 from cat');
  Check(LBuf[0] = 'p', 'data[0] = p');
  nextpas.core.platform.posix.ffi.close(Pipes.StdoutRead);
  nextpas.core.platform.posix.ffi.close(Pipes.StderrRead);
  platform_process_wait(P, R);
  Check(R.ExitCode = 0, 'exit 0');
end;

procedure TestRun;
var
  LArgv: array[0..2] of PAnsiChar;
  LBuf: array[0..255] of AnsiChar;
  LOutLen, LExitCode: Int32;
begin
  LArgv[0] := '/bin/echo';
  LArgv[1] := 'world';
  LArgv[2] := nil;
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_process_run('/bin/echo', @LArgv[0], nil, @LBuf[0], 256, LOutLen, LExitCode) = 0, 'run ok');
  Check(LExitCode = 0, 'exit 0');
  Check(LOutLen >= 5, 'output >= 5');
  Check(LBuf[0] = 'w', 'output[0] = w');
end;

procedure TestRunCwd;
var
  LArgv: array[0..2] of PAnsiChar;
  LBuf: array[0..1023] of AnsiChar;
  LOutLen, LExitCode: Int32;
begin
  LArgv[0] := '/bin/pwd';
  LArgv[1] := nil;
  LArgv[2] := nil;
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_process_run('/bin/pwd', @LArgv[0], '/tmp', @LBuf[0], 1024, LOutLen, LExitCode) = 0, 'run cwd ok');
  Check(LExitCode = 0, 'exit 0');
  Check(LOutLen >= 4, 'output >= 4');
  Check((LBuf[0] = '/') and (LBuf[1] = 't') and (LBuf[2] = 'm') and (LBuf[3] = 'p'), 'cwd is /tmp');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.process');
  T.Run('spawn /bin/true', @TestSpawnTrue);
  T.Run('spawn /bin/false exit 1', @TestSpawnFalse);
  T.Run('pid accessor', @TestPid);
  T.Run('kill', @TestKill);
  T.Run('try_wait non-blocking', @TestTryWait);
  T.Run('spawn non-existent', @TestSpawnNonExistent);
  T.Run('spawn with args', @TestSpawnWithArgs);
  T.Run('piped: capture stdout', @TestSpawnPipedStdout);
  T.Run('piped: capture stderr', @TestSpawnPipedStderr);
  T.Run('piped: write stdin', @TestSpawnPipedStdin);
  T.Run('run: capture output', @TestRun);
  T.Run('run: working directory', @TestRunCwd);
  T.Summary;
end.
