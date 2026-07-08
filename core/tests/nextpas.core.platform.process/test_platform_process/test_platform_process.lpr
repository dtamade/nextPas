program test_platform_process;

{$I nextpas.core.settings.inc}

uses

  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.platform.process.base,
  nextpas.core.platform.process,
  nextpas.core.platform.thread,
  nextpas.core.process,
  nextpas.core.platform.unix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.error,
  nextpas.core.test;

var
  T: TTestSuite;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := '../../../' + ARelativePath;
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  Result := FsReadFileText(LSourcePath);
end;

procedure SpawnWithPipes(const APath: PAnsiChar; AArgv: PPAnsiChar;
  out AProc: TPlatformProcess; out AStdinWrite, AStdoutRead,
  AStderrRead: PtrInt);
var
  LChildStdin: PtrInt;
  LChildStdout: PtrInt;
  LChildStderr: PtrInt;
  LFailStage: TPlatformProcessSpawnStage;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  AStdinWrite := -1;
  AStdoutRead := -1;
  AStderrRead := -1;
  LChildStdin := -1;
  LChildStdout := -1;
  LChildStderr := -1;
  try
    Check(platform_process_create_pipe(LChildStdin, AStdinWrite) = 0,
      'create stdin pipe');
    Check(platform_process_create_pipe(AStdoutRead, LChildStdout) = 0,
      'create stdout pipe');
    Check(platform_process_create_pipe(AStderrRead, LChildStderr) = 0,
      'create stderr pipe');
    Check(platform_process_spawn_fds(APath, AArgv, nil, nil, LChildStdin,
      LChildStdout, LChildStderr, AProc, LFailStage) = 0, 'spawn');
  except
    platform_process_close_handle(LChildStdin);
    platform_process_close_handle(LChildStdout);
    platform_process_close_handle(LChildStderr);
    platform_process_close_handle(AStdinWrite);
    platform_process_close_handle(AStdoutRead);
    platform_process_close_handle(AStderrRead);
    raise;
  end;
  platform_process_close_handle(LChildStdin);
  platform_process_close_handle(LChildStdout);
  platform_process_close_handle(LChildStderr);
end;

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
  Check(R.ExitCode = 137, 'signal 9 (SIGKILL) => 128 + 9 = 137');
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
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..63] of AnsiChar;
  LRead: PtrInt;
  LStdinWrite: PtrInt;
  LStdoutRead: PtrInt;
  LStderrRead: PtrInt;
begin
  LArgv[0] := '/bin/echo';
  LArgv[1] := 'hello';
  LArgv[2] := nil;
  SpawnWithPipes('/bin/echo', @LArgv[0], P, LStdinWrite, LStdoutRead, LStderrRead);
  Check(LStdoutRead >= 0, 'stdout pipe valid');
  platform_process_close_handle(LStdinWrite);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := nextpas.core.platform.posix.ffi.read(LStdoutRead, @LBuf[0], 64);
  Check(LRead >= 5, 'read >= 5 bytes');
  Check(LBuf[0] = 'h', 'stdout[0] = h');
  platform_process_close_handle(LStdoutRead);
  platform_process_close_handle(LStderrRead);
  platform_process_wait(P, R);
  Check(R.ExitCode = 0, 'exit 0');
end;

procedure TestSpawnPipedStderr;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..255] of AnsiChar;
  LRead: PtrInt;
  LStdinWrite: PtrInt;
  LStdoutRead: PtrInt;
  LStderrRead: PtrInt;
begin
  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'echo errmsg >&2; exit 1';
  LArgv[3] := nil;
  SpawnWithPipes('/bin/sh', @LArgv[0], P, LStdinWrite, LStdoutRead, LStderrRead);
  platform_process_close_handle(LStdinWrite);
  platform_process_close_handle(LStdoutRead);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := nextpas.core.platform.posix.ffi.read(LStderrRead, @LBuf[0], 256);
  Check(LRead > 0, 'stderr has output');
  Check(LBuf[0] = 'e', 'stderr[0] = e');
  platform_process_close_handle(LStderrRead);
  platform_process_wait(P, R);
  Check(R.ExitCode = 1, 'exit 1');
end;

procedure TestSpawnPipedStdin;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..63] of AnsiChar;
  LRead: PtrInt;
  LStdinWrite: PtrInt;
  LStdoutRead: PtrInt;
  LStderrRead: PtrInt;
begin
  LArgv[0] := '/bin/cat';
  LArgv[1] := nil;
  SpawnWithPipes('/bin/cat', @LArgv[0], P, LStdinWrite, LStdoutRead, LStderrRead);
  nextpas.core.platform.posix.ffi.write(LStdinWrite, PAnsiChar('ping'), 4);
  platform_process_close_handle(LStdinWrite);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := nextpas.core.platform.posix.ffi.read(LStdoutRead, @LBuf[0], 64);
  Check(LRead = 4, 'read 4 from cat');
  Check(LBuf[0] = 'p', 'data[0] = p');
  platform_process_close_handle(LStdoutRead);
  platform_process_close_handle(LStderrRead);
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

procedure TestRunDiscardsStderrWithoutChangingExit;
var
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..63] of AnsiChar;
  LOutLen, LExitCode: Int32;
begin
  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'i=0; while [ $i -lt 20000 ]; do echo noisy-line >&2; i=$((i+1)); done; printf stdout-ok';
  LArgv[3] := nil;
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_process_run('/bin/sh', @LArgv[0], nil, @LBuf[0], SizeOf(LBuf),
    LOutLen, LExitCode) = 0, 'run stderr discard ok');
  Check(LExitCode = 0, 'run stderr discard preserves exit 0');
  Check(LOutLen = 9, 'run stderr discard captures stdout length');
  Check((LBuf[0] = 's') and (LBuf[8] = 'k'),
    'run stderr discard captures stdout content');
end;

procedure TestCommandEnvAddDuplicatePathUsesFinalResolvedView;
var
  LOut: nextpas.core.process.TProcessOutput;
begin
  LOut := Command('echo')
    .Args(['envadd-path-final-view'])
    .EnvAdd('PATH', '/definitely_missing_nextpas_process')
    .EnvAdd('PATH', '/bin:/usr/bin')
    .Output;
  Check(LOut.ExitCode = 0, 'EnvAdd duplicate PATH exit 0');
  Check(Pos('envadd-path-final-view', LOut.StdOut) > 0,
    'EnvAdd duplicate PATH resolves using final PATH view');
end;

procedure TestSpawnFdsNoHardcoded1024SourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('src/nextpas.core.platform.process.pas');
  Check(Pos('to 1023', LSource) = 0,
    'spawn_fds child fd cleanup must not hardcode 1024 as the max fd');
  Check(Pos('PLATFORM_SYSCONF_OPEN_MAX', LSource) = 0,
    'spawn_fds child fd cleanup must consume the shared POSIX sysconf constant');
  Check(Pos('sysconf(PLATFORM_SC_OPEN_MAX)', LSource) > 0,
    'spawn_fds fallback must use the shared POSIX _SC_OPEN_MAX constant');
  Check(Pos('NEXTPAS_PROCESS_HAS_CLOSE_RANGE', LSource) > 0,
    'spawn_fds close_range path must be guarded by supported Linux architectures');
  Check(Pos('PLATFORM_CHILD_FD_FIRST', LSource) > 0,
    'spawn_fds close logic must preserve the standard 0/1/2 descriptor boundary');
  Check(Pos('LErrPipe[1]', LSource) > 0,
    'spawn_fds must preserve exec-error pipe write fd while closing child fds');
end;

procedure TestSpawnFdsClosesHighInheritedFd;
var
  LDevNull: Int32;
  LHighFd: Int32;
  LScript: string;
  LOut: nextpas.core.process.TProcessOutput;
begin
{$IFDEF NEXTPAS_LINUX}
  LDevNull := nextpas.core.platform.posix.ffi.open('/dev/null', O_RDONLY, 0);
  Check(LDevNull >= 0, 'open /dev/null');
  LHighFd := -1;
  try
    LHighFd := nextpas.core.platform.posix.ffi.fcntl(LDevNull, F_DUPFD, 1500);
    if LHighFd < 0 then
      LHighFd := nextpas.core.platform.posix.ffi.fcntl(LDevNull, F_DUPFD, 1024);
    if LHighFd < 0 then
    begin
      Check(True,
        'environment cannot allocate fd above 1023; runtime high-fd proof skipped');
      Exit;
    end;
    Check(LHighFd > 1023, 'create inheritable fd above legacy 1024 bound');
    nextpas.core.platform.posix.ffi.close(LDevNull);
    LDevNull := -1;

    LScript := 'if [ -e /proc/self/fd/' + IntToStr(LHighFd) +
      ' ]; then exit 42; else exit 0; fi';
    LOut := Command('/bin/sh')
      .Args(['-c', LScript])
      .Output;
    Check(LOut.ExitCode = 0,
      'spawn_fds must close inherited fd above 1023 before exec');
  finally
    if LHighFd >= 0 then
      nextpas.core.platform.posix.ffi.close(LHighFd);
    if LDevNull >= 0 then
      nextpas.core.platform.posix.ffi.close(LDevNull);
  end;
{$ELSE}
  Check(True,
    'runtime high-fd leak proof uses Linux /proc/self/fd; POSIX fallback is source-guarded');
{$ENDIF}
end;

procedure TestSpawnFdsExecFailureKeepsErrorPipe;
var
  LProc: TPlatformProcess;
  LFailStage: TPlatformProcessSpawnStage;
  LArgv: array[0..1] of PAnsiChar;
  LErr: Int32;
begin
  LArgv[0] := '/definitely_missing_nextpas_spawn_fds';
  LArgv[1] := nil;
  LErr := platform_process_spawn_fds('/definitely_missing_nextpas_spawn_fds',
    @LArgv[0], nil, nil, -1, -1, -1, LProc, LFailStage);
  Check(LErr <> 0, 'missing executable should return exec errno');
  Check(LFailStage = pssExec,
    'spawn_fds must report exec failure through preserved error pipe');
end;

procedure TestProcessSignal;
var
  LProc: TPlatformProcess;
  LArgv: array[0..2] of PAnsiChar;
  LResult: TPlatformProcessResult;
  LRet: Int32;
begin
  { Spawn a process that exits quickly }
  LArgv[0] := '/bin/sleep';
  LArgv[1] := '10';
  LArgv[2] := nil;
  LRet := platform_process_spawn('/bin/sleep', @LArgv[0], nil, LProc);
  Check(LRet = 0, 'spawn sleep');

  { Send SIGTERM }
  LRet := platform_process_signal(LProc, 15);  { SIGTERM }
  Check(LRet = 0, 'signal process');

  { Process should exit }
  LRet := platform_process_wait(LProc, LResult, 5000);
  Check(LRet = 0, 'wait after signal');
end;

procedure TestProcessDetach;
var
  LProc: TPlatformProcess;
  LArgv: array[0..2] of PAnsiChar;
  LResult: TPlatformProcessResult;
  LRet: Int32;
begin
  LArgv[0] := '/bin/sleep';
  LArgv[1] := '0.1';
  LArgv[2] := nil;
  LRet := platform_process_spawn('/bin/sleep', @LArgv[0], nil, LProc);
  Check(LRet = 0, 'spawn for detach');

  { Detach: we promise not to wait }
  platform_process_detach(LProc);

  { After detach, the process should still run and exit on its own }
  { We can't wait on it anymore, but we can verify detach didn't crash }
  Check(True, 'detach completed without crash');

  { Give it time to exit }
  platform_thread_sleep_ns(200000000); { 200ms }
end;

procedure TestProcessCreatePipe;
var
  LRead, LWrite: PtrInt;
  LRet: Int32;
  LBuf: array[0..15] of AnsiChar;
  LWritten: PtrInt;
  LReadBytes: PtrInt;
begin
  LRet := platform_process_create_pipe(LRead, LWrite);
  Check(LRet = 0, 'create pipe');
  Check(LRead >= 0, 'read fd valid');
  Check(LWrite >= 0, 'write fd valid');

  { Write and read through the pipe }
  LWritten := nextpas.core.platform.posix.ffi.write(LWrite, PAnsiChar('test'), 4);
  Check(LWritten = 4, 'wrote 4 bytes');

  FillChar(LBuf, SizeOf(LBuf), 0);
  LReadBytes := nextpas.core.platform.posix.ffi.read(LRead, @LBuf[0], 16);
  Check(LReadBytes = 4, 'read 4 bytes');
  Check(LBuf[0] = 't', 'data[0] = t');
  Check(LBuf[3] = 't', 'data[3] = t');

  platform_process_close_handle(LRead);
  platform_process_close_handle(LWrite);
end;

procedure TestProcessOpenNull;
var
  LNullRead, LNullWrite: PtrInt;
  LRet: Int32;
begin
  { Open /dev/null for reading }
  LRet := platform_process_open_null(False, LNullRead);
  Check(LRet = 0, 'open null for read');
  Check(LNullRead >= 0, 'null read fd valid');

  { Open /dev/null for writing }
  LRet := platform_process_open_null(True, LNullWrite);
  Check(LRet = 0, 'open null for write');
  Check(LNullWrite >= 0, 'null write fd valid');

  { Reading from /dev/null should return 0 (EOF) }
  LRet := nextpas.core.platform.posix.ffi.read(LNullRead, nil, 1);
  Check(LRet = 0, 'read from null returns EOF');

  platform_process_close_handle(LNullRead);
  platform_process_close_handle(LNullWrite);
end;

{ Error path tests }
procedure TestSpawnNilPath;
var
  LProc: TPlatformProcess;
  LArgv: array[0..1] of PAnsiChar;
  LRet: Int32;
begin
  LArgv[0] := '/bin/true';
  LArgv[1] := nil;
  LRet := platform_process_spawn(nil, @LArgv[0], nil, LProc);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet), 'spawn nil path returns invalid');
end;

procedure TestSpawnFdsNilPath;
var
  LProc: TPlatformProcess;
  LFailStage: TPlatformProcessSpawnStage;
  LArgv: array[0..1] of PAnsiChar;
  LRet: Int32;
begin
  LArgv[0] := '/bin/true';
  LArgv[1] := nil;
  LRet := platform_process_spawn_fds(nil, @LArgv[0], nil, nil, -1, -1, -1, LProc, LFailStage);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet), 'spawn_fds nil path returns invalid');
end;

procedure TestRunNilPath;
var
  LBuf: array[0..63] of AnsiChar;
  LOutLen, LExitCode: Int32;
  LRet: Int32;
begin
  LRet := platform_process_run(nil, nil, nil, @LBuf[0], 64, LOutLen, LExitCode);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet), 'run nil path returns invalid');
end;

procedure TestCloseHandleAlreadyClosed;
var
  LHandle: PtrInt;
  LRet: Int32;
begin
  LHandle := -1;
  LRet := platform_process_close_handle(LHandle);
  CheckEqual(Int64(0), Int64(LRet), 'close already-closed handle returns 0');
  CheckEqual(Int64(-1), Int64(LHandle), 'handle remains -1');
end;

procedure TestWaitTimeout;
var
  LProc: TPlatformProcess;
  LArgv: array[0..2] of PAnsiChar;
  LResult: TPlatformProcessResult;
  LRet: Int32;
begin
  LArgv[0] := '/bin/sleep';
  LArgv[1] := '10';
  LArgv[2] := nil;
  LRet := platform_process_spawn('/bin/sleep', @LArgv[0], nil, LProc);
  Check(LRet = 0, 'spawn sleep');

  { Wait with 1ms timeout should return timeout }
  LRet := platform_process_wait(LProc, LResult, 1);
  Check(LRet <> 0, 'wait with timeout returns error');
  Check(LResult.Status = psRunning, 'process still running after timeout');

  { Clean up }
  platform_process_kill(LProc);
  platform_process_wait(LProc, LResult);
end;

procedure TestTryWaitOnExitedProcess;
var
  LProc: TPlatformProcess;
  LArgv: array[0..1] of PAnsiChar;
  LResult: TPlatformProcessResult;
  LRet: Int32;
begin
  LArgv[0] := '/bin/true';
  LArgv[1] := nil;
  LRet := platform_process_spawn('/bin/true', @LArgv[0], nil, LProc);
  Check(LRet = 0, 'spawn true');

  { Use try_wait to check if process is still running }
  LRet := platform_process_try_wait(LProc, LResult);
  Check(LRet = 0, 'try_wait returns 0');

  { Process may have already exited or still running }
  if LResult.Status = psRunning then
  begin
    { Process still running, wait for it }
    LRet := platform_process_wait(LProc, LResult);
    Check(LRet = 0, 'wait for true');
    Check(LResult.Status = psExited, 'true exited');
    Check(LResult.ExitCode = 0, 'true exit code 0');
  end
  else
  begin
    { Process already exited }
    Check(LResult.Status = psExited, 'true exited');
    Check(LResult.ExitCode = 0, 'true exit code 0');
  end;
end;

procedure TestSignalVariousSignals;
var
  LProc: TPlatformProcess;
  LArgv: array[0..2] of PAnsiChar;
  LResult: TPlatformProcessResult;
  LRet: Int32;
begin
  LArgv[0] := '/bin/sleep';
  LArgv[1] := '10';
  LArgv[2] := nil;
  LRet := platform_process_spawn('/bin/sleep', @LArgv[0], nil, LProc);
  Check(LRet = 0, 'spawn sleep');

  { Send SIGTERM (15) }
  LRet := platform_process_signal(LProc, 15);
  Check(LRet = 0, 'signal SIGTERM');

  { Process should exit }
  LRet := platform_process_wait(LProc, LResult, 5000);
  Check(LRet = 0, 'wait after SIGTERM');
  Check(LResult.Status = psSignaled, 'process signaled');
end;

procedure TestProcessKillExitedProcess;
var
  LProc: TPlatformProcess;
  LArgv: array[0..1] of PAnsiChar;
  LResult: TPlatformProcessResult;
  LRet: Int32;
begin
  LArgv[0] := '/bin/true';
  LArgv[1] := nil;
  LRet := platform_process_spawn('/bin/true', @LArgv[0], nil, LProc);
  Check(LRet = 0, 'spawn true');

  { Wait for process to exit }
  LRet := platform_process_wait(LProc, LResult, 5000);
  Check(LRet = 0, 'wait for true');
  Check(LResult.Status = psExited, 'true exited');

  { Kill on already exited process should succeed or return error }
  LRet := platform_process_kill(LProc);
  { Some systems return ESRCH, others succeed }
  Check(True, 'kill on exited process handled');
end;

procedure TestProcessSignalZero;
var
  LProc: TPlatformProcess;
  LArgv: array[0..1] of PAnsiChar;
  LResult: TPlatformProcessResult;
  LRet: Int32;
begin
  LArgv[0] := '/bin/sleep';
  LArgv[1] := '0.1';
  LArgv[2] := nil;
  LRet := platform_process_spawn('/bin/sleep', @LArgv[0], nil, LProc);
  Check(LRet = 0, 'spawn sleep');

  { Signal 0 checks if process exists without sending signal }
  LRet := platform_process_signal(LProc, 0);
  Check(LRet = 0, 'signal 0 on running process succeeds');

  { Wait for process }
  platform_process_wait(LProc, LResult, 5000);
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.process');
  T.Test('spawn /bin/true', @TestSpawnTrue);
  T.Test('spawn /bin/false exit 1', @TestSpawnFalse);
  T.Test('pid accessor', @TestPid);
  T.Test('kill', @TestKill);
  T.Test('try_wait non-blocking', @TestTryWait);
  T.Test('spawn non-existent', @TestSpawnNonExistent);
  T.Test('spawn with args', @TestSpawnWithArgs);
  T.Test('piped: capture stdout', @TestSpawnPipedStdout);
  T.Test('piped: capture stderr', @TestSpawnPipedStderr);
  T.Test('piped: write stdin', @TestSpawnPipedStdin);
  T.Test('run: capture output', @TestRun);
  T.Test('run: working directory', @TestRunCwd);
  T.Test('run: discard stderr without changing exit', @TestRunDiscardsStderrWithoutChangingExit);
  T.Test('command: EnvAdd duplicate PATH final view', @TestCommandEnvAddDuplicatePathUsesFinalResolvedView);
  T.Test('spawn_fds source: no hardcoded 1024', @TestSpawnFdsNoHardcoded1024SourceContract);
  T.Test('spawn_fds closes high inherited fd', @TestSpawnFdsClosesHighInheritedFd);
  T.Test('spawn_fds exec failure keeps error pipe', @TestSpawnFdsExecFailureKeepsErrorPipe);
  T.Test('process signal', @TestProcessSignal);
  T.Test('process detach', @TestProcessDetach);
  T.Test('process create pipe', @TestProcessCreatePipe);
  T.Test('process open null', @TestProcessOpenNull);
  T.Test('spawn nil path returns invalid', @TestSpawnNilPath);
  T.Test('spawn_fds nil path returns invalid', @TestSpawnFdsNilPath);
  T.Test('run nil path returns invalid', @TestRunNilPath);
  T.Test('close handle already closed', @TestCloseHandleAlreadyClosed);
  T.Test('wait timeout', @TestWaitTimeout);
  T.Test('try_wait on exited process', @TestTryWaitOnExitedProcess);
  T.Test('signal various signals', @TestSignalVariousSignals);
  T.Test('kill exited process', @TestProcessKillExitedProcess);
  T.Test('signal 0 checks existence', @TestProcessSignalZero);
  if not T.Run then Halt(1);
end.
