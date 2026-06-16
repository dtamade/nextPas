program test_platform_process;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.platform.process.base,
  nextpas.core.platform.process,
  nextpas.core.process,
  nextpas.core.platform.unix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.testing;

var
  T: TTestRunner;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('../../../' + ARelativePath);
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
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
  T.Run('run: discard stderr without changing exit', @TestRunDiscardsStderrWithoutChangingExit);
  T.Run('command: EnvAdd duplicate PATH final view', @TestCommandEnvAddDuplicatePathUsesFinalResolvedView);
  T.Run('spawn_fds source: no hardcoded 1024', @TestSpawnFdsNoHardcoded1024SourceContract);
  T.Run('spawn_fds closes high inherited fd', @TestSpawnFdsClosesHighInheritedFd);
  T.Run('spawn_fds exec failure keeps error pipe', @TestSpawnFdsExecFailureKeepsErrorPipe);
  T.Summary;
end.
