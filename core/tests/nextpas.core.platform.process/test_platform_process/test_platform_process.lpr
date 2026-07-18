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

const
  OUTPUT_DRAIN_PROBE_ARG = '--output-drain-probe';

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

function CountSubstring(const AText: string; const APattern: string): Integer;
var
  LText: string;
  LPos: SizeInt;
begin
  Result := 0;
  if APattern = '' then
    Exit;
  LText := AText;
  repeat
    LPos := Pos(APattern, LText);
    if LPos = 0 then
      Exit;
    Inc(Result);
    Delete(LText, 1, LPos + Length(APattern) - 1);
  until False;
end;

function RunOutputDrainProbe: Int32;
var
  LArgv: array[0..3] of PAnsiChar;
  LRunBuf: array[0..7] of AnsiChar;
  LStdoutBuf: array[0..7] of AnsiChar;
  LStderrBuf: array[0..7] of AnsiChar;
  LRunLen, LRunExitCode: Int32;
  LStdoutLen, LStderrLen, LExitCode: Int32;
begin
  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] :=
    'i=0; while [ $i -lt 16384 ]; do printf 0123456789abcdef; i=$((i+1)); done';
  LArgv[3] := nil;
  FillChar(LRunBuf, SizeOf(LRunBuf), 0);
  FillChar(LStdoutBuf, SizeOf(LStdoutBuf), 0);
  FillChar(LStderrBuf, SizeOf(LStderrBuf), 0);

  Result := platform_process_run('/bin/sh', @LArgv[0], nil,
    @LRunBuf[0], SizeOf(LRunBuf), LRunLen, LRunExitCode);
  if Result <> 0 then
    Exit(5);
  if LRunLen <> SizeOf(LRunBuf) then
    Exit(6);
  if LRunExitCode <> 0 then
    Exit(7);

  Result := platform_process_run_capture('/bin/sh', @LArgv[0], nil,
    @LStdoutBuf[0], SizeOf(LStdoutBuf), LStdoutLen,
    @LStderrBuf[0], SizeOf(LStderrBuf), LStderrLen, LExitCode);
  if Result <> 0 then
    Exit(10);
  if LStdoutLen <> SizeOf(LStdoutBuf) then
    Exit(11);
  if LStderrLen <> 0 then
    Exit(12);
  if LExitCode <> 0 then
    Exit(13);
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

procedure TestSpawnPipedIoEx;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..1] of PAnsiChar;
  LBuf: array[0..63] of AnsiChar;
  LErr: Int32;
  LWritten: Int32;
  LRead: Int32;
  LStdinWrite: PtrInt;
  LStdoutRead: PtrInt;
  LStderrRead: PtrInt;
begin
  LArgv[0] := '/bin/cat';
  LArgv[1] := nil;
  SpawnWithPipes('/bin/cat', @LArgv[0], P, LStdinWrite, LStdoutRead, LStderrRead);

  LErr := platform_process_write_stdin_ex(LStdinWrite, PAnsiChar('ping'), 4,
    LWritten);
  Check(LErr = 0, 'write_stdin_ex succeeds');
  Check(LWritten = 4, 'write_stdin_ex writes 4 bytes');
  platform_process_close_handle(LStdinWrite);

  FillChar(LBuf, SizeOf(LBuf), 0);
  LErr := platform_process_read_stdout_ex(LStdoutRead, @LBuf[0], SizeOf(LBuf),
    LRead);
  Check(LErr = 0, 'read_stdout_ex succeeds');
  Check(LRead = 4, 'read_stdout_ex reads 4 bytes');
  Check(LBuf[0] = 'p', 'stdout_ex data[0] = p');

  platform_process_close_handle(LStdoutRead);
  platform_process_close_handle(LStderrRead);
  platform_process_wait(P, R);
  Check(R.ExitCode = 0, 'exit 0');
end;

procedure TestSpawnPipedStderrEx;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..255] of AnsiChar;
  LErr: Int32;
  LRead: Int32;
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
  LErr := platform_process_read_stderr_ex(LStderrRead, @LBuf[0], SizeOf(LBuf),
    LRead);
  Check(LErr = 0, 'read_stderr_ex succeeds');
  Check(LRead > 0, 'read_stderr_ex returns data');
  Check(LBuf[0] = 'e', 'stderr_ex data[0] = e');

  platform_process_close_handle(LStderrRead);
  platform_process_wait(P, R);
  Check(R.ExitCode = 1, 'exit 1');
end;

procedure TestPipeIoExRejectsInvalidBuffers;
var
  LErr: Int32;
  LCount: Int32;
begin
  LCount := 123;
  LErr := platform_process_write_stdin_ex(-1, PAnsiChar('x'), 1, LCount);
  Check(LErr = PLATFORM_ERR_INVALID, 'write_stdin_ex rejects invalid handle');
  Check(LCount = 0, 'write_stdin_ex clears bytes on invalid handle');

  LCount := 123;
  LErr := platform_process_read_stdout_ex(-1, nil, 4, LCount);
  Check(LErr = PLATFORM_ERR_INVALID, 'read_stdout_ex rejects invalid buffer');
  Check(LCount = 0, 'read_stdout_ex clears bytes on invalid buffer');

  LCount := 123;
  LErr := platform_process_read_stderr_ex(-1, nil, 4, LCount);
  Check(LErr = PLATFORM_ERR_INVALID, 'read_stderr_ex rejects invalid buffer');
  Check(LCount = 0, 'read_stderr_ex clears bytes on invalid buffer');
end;

procedure TestPipeIoExZeroLength;
var
  LErr: Int32;
  LCount: Int32;
  LBuf: array[0..3] of AnsiChar;
begin
  LCount := 123;
  LErr := platform_process_write_stdin_ex(0, nil, 0, LCount);
  Check(LErr = 0, 'write_stdin_ex accepts zero length');
  Check(LCount = 0, 'write_stdin_ex zero length writes 0');

  LCount := 123;
  LErr := platform_process_read_stdout_ex(0, nil, 0, LCount);
  Check(LErr = 0, 'read_stdout_ex accepts zero length');
  Check(LCount = 0, 'read_stdout_ex zero length reads 0');

  LCount := 123;
  FillChar(LBuf, SizeOf(LBuf), 0);
  LErr := platform_process_read_stderr_ex(0, @LBuf[0], 0, LCount);
  Check(LErr = 0, 'read_stderr_ex accepts zero length');
  Check(LCount = 0, 'read_stderr_ex zero length reads 0');
end;

{$PUSH}{$WARN 6058 OFF} { allow deprecated legacy pipe I/O in compatibility tests }
procedure TestLegacyPipeIoRoundtrip;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..1] of PAnsiChar;
  LBuf: array[0..63] of AnsiChar;
  LWritten: Int32;
  LRead: Int32;
  LStdinWrite: PtrInt;
  LStdoutRead: PtrInt;
  LStderrRead: PtrInt;
begin
  LArgv[0] := '/bin/cat';
  LArgv[1] := nil;
  SpawnWithPipes('/bin/cat', @LArgv[0], P, LStdinWrite, LStdoutRead, LStderrRead);

  LWritten := platform_process_write_stdin(LStdinWrite, PAnsiChar('pong'), 4);
  Check(LWritten = 4, 'legacy write_stdin returns byte count');
  platform_process_close_handle(LStdinWrite);

  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := platform_process_read_stdout(LStdoutRead, @LBuf[0], SizeOf(LBuf));
  Check(LRead = 4, 'legacy read_stdout returns byte count');
  Check(LBuf[0] = 'p', 'legacy read_stdout data[0] = p');

  Check(platform_process_write_stdin(-1, PAnsiChar('x'), 1) = -1,
    'legacy write_stdin fails with -1');
  Check(platform_process_read_stdout(-1, @LBuf[0], 4) = -1,
    'legacy read_stdout fails with -1');
  Check(platform_process_read_stderr(-1, @LBuf[0], 4) = -1,
    'legacy read_stderr fails with -1');

  platform_process_close_handle(LStdoutRead);
  platform_process_close_handle(LStderrRead);
  platform_process_wait(P, R);
  Check(R.ExitCode = 0, 'exit 0');
end;
{$POP}

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

procedure TestRunCapturePreservesShortLengths;
var
  LArgv: array[0..3] of PAnsiChar;
  LStdoutBuf: array[0..63] of AnsiChar;
  LStderrBuf: array[0..63] of AnsiChar;
  LStdoutLen, LStderrLen, LExitCode: Int32;
begin
  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'printf out; printf err >&2';
  LArgv[3] := nil;
  FillChar(LStdoutBuf, SizeOf(LStdoutBuf), 0);
  FillChar(LStderrBuf, SizeOf(LStderrBuf), 0);

  Check(platform_process_run_capture('/bin/sh', @LArgv[0], nil,
    @LStdoutBuf[0], SizeOf(LStdoutBuf), LStdoutLen,
    @LStderrBuf[0], SizeOf(LStderrBuf), LStderrLen, LExitCode) = 0,
    'run_capture succeeds');
  CheckEqual(Int64(3), Int64(LStdoutLen),
    'run_capture preserves actual stdout length after EOF');
  CheckEqual(Int64(3), Int64(LStderrLen),
    'run_capture preserves actual stderr length after EOF');
  Check((LStdoutBuf[0] = 'o') and (LStdoutBuf[2] = 't'),
    'run_capture preserves stdout content');
  Check((LStderrBuf[0] = 'e') and (LStderrBuf[2] = 'r'),
    'run_capture preserves stderr content');
  CheckEqual(Int64(0), Int64(LExitCode), 'run_capture exit code');
end;

procedure TestRunRejectsNilOutputBufferWithCapacity;
var
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..0] of AnsiChar;
  LOutLen, LExitCode: Int32;
  LRet: Int32;
begin
  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'printf output';
  LArgv[3] := nil;

  LRet := platform_process_run('/bin/sh', @LArgv[0], nil, nil, 16,
    LOutLen, LExitCode);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet),
    'run rejects nil output buffer with positive capacity');
  CheckEqual(Int64(0), Int64(LOutLen),
    'run leaves output length zero after invalid buffer');
  CheckEqual(Int64(-1), Int64(LExitCode),
    'run leaves exit code unset after invalid buffer');

  LRet := platform_process_run('/bin/true', nil, nil, @LBuf[0], -1,
    LOutLen, LExitCode);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet),
    'run rejects negative output capacity');
end;

procedure TestRunCaptureRejectsInvalidBuffers;
var
  LBuf: array[0..15] of AnsiChar;
  LStdoutLen, LStderrLen, LExitCode: Int32;
  LRet: Int32;
begin
  LRet := platform_process_run_capture('/bin/true', nil, nil,
    nil, 16, LStdoutLen, @LBuf[0], SizeOf(LBuf), LStderrLen, LExitCode);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet),
    'run_capture rejects nil stdout buffer with positive capacity');

  LRet := platform_process_run_capture('/bin/true', nil, nil,
    @LBuf[0], SizeOf(LBuf), LStdoutLen, nil, 16, LStderrLen, LExitCode);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet),
    'run_capture rejects nil stderr buffer with positive capacity');

  LRet := platform_process_run_capture('/bin/true', nil, nil,
    @LBuf[0], -1, LStdoutLen, @LBuf[0], SizeOf(LBuf),
    LStderrLen, LExitCode);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet),
    'run_capture rejects negative output capacity');
end;

procedure TestRunHelpersDrainAfterBuffersFill;
var
  LProc: TPlatformProcess;
  LResult: TPlatformProcessResult;
  LArgv: array[0..2] of PAnsiChar;
  LExePath: string;
  LRet: Int32;
begin
  LExePath := ParamStr(0);
  LArgv[0] := PAnsiChar(LExePath);
  LArgv[1] := OUTPUT_DRAIN_PROBE_ARG;
  LArgv[2] := nil;
  Check(platform_process_spawn(PAnsiChar(LExePath), @LArgv[0], nil, LProc) = 0,
    'spawn output drain probe');

  LRet := platform_process_wait(LProc, LResult, 3000);
  if LRet <> 0 then
  begin
    platform_process_kill(LProc);
    platform_process_wait(LProc, LResult);
    Check(False,
      'process run helpers must drain data after caller buffers fill');
    Exit;
  end;
  CheckEqual(Int64(0), Int64(LResult.ExitCode),
    'output drain probe exits successfully');
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

procedure TestWindowsRunCaptureStdoutOnlySourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('src/nextpas.core.platform.process.pas');
  Check(Pos('Windows implementation currently captures stdout only', LSource) > 0,
    'run_capture interface docs must state Windows stdout-only limitation');
end;

procedure TestUnsupportedPipeIoStubSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('src/nextpas.core.platform.process.pas');
  { Unsupported host stubs for pipe I/O must use PLATFORM_ERR_UNSUPPORTED.
    Do not ban all "Result := -1" — value/sentinel helpers (getpid, io_*) may
    still use -1 on unsupported hosts. }
  Check(Pos(
    'function platform_process_write_stdin_ex(AStdinWrite: PtrInt;' + LineEnding +
    '  AData: PAnsiChar; ALen: Int32; out ABytesWritten: Int32): Int32;' + LineEnding +
    'begin ABytesWritten := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;',
    LSource) > 0,
    'write_stdin_ex unsupported stub must return PLATFORM_ERR_UNSUPPORTED');
  Check(Pos(
    'function platform_process_read_stdout_ex(AStdoutRead: PtrInt;' + LineEnding +
    '  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;' + LineEnding +
    'begin ABytesRead := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;',
    LSource) > 0,
    'read_stdout_ex unsupported stub must return PLATFORM_ERR_UNSUPPORTED');
  Check(Pos(
    'function platform_process_read_stderr_ex(AStderrRead: PtrInt;' + LineEnding +
    '  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;' + LineEnding +
    'begin ABytesRead := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;',
    LSource) > 0,
    'read_stderr_ex unsupported stub must return PLATFORM_ERR_UNSUPPORTED');
  Check(Pos(
    'function platform_process_write_stdin(AStdinWrite: PtrInt;' + LineEnding +
    '  AData: PAnsiChar; ALen: Int32): Int32; deprecated ''Use platform_process_write_stdin_ex'';' +
    LineEnding +
    'begin Result := PLATFORM_ERR_UNSUPPORTED; end;',
    LSource) > 0,
    'legacy write_stdin unsupported stub must return PLATFORM_ERR_UNSUPPORTED');
  Check(Pos(
    'function platform_process_read_stdout(AStdoutRead: PtrInt;' + LineEnding +
    '  ABuf: PAnsiChar; ABufLen: Int32): Int32; deprecated ''Use platform_process_read_stdout_ex'';' +
    LineEnding +
    'begin Result := PLATFORM_ERR_UNSUPPORTED; end;',
    LSource) > 0,
    'legacy read_stdout unsupported stub must return PLATFORM_ERR_UNSUPPORTED');
  Check(Pos(
    'function platform_process_read_stderr(AStderrRead: PtrInt;' + LineEnding +
    '  ABuf: PAnsiChar; ABufLen: Int32): Int32; deprecated ''Use platform_process_read_stderr_ex'';' +
    LineEnding +
    'begin Result := PLATFORM_ERR_UNSUPPORTED; end;',
    LSource) > 0,
    'legacy read_stderr unsupported stub must return PLATFORM_ERR_UNSUPPORTED');
  Check(Pos(
    'function platform_process_write_stdin(AStdinWrite: PtrInt;' + LineEnding +
    '  AData: PAnsiChar; ALen: Int32): Int32;' + LineEnding +
    'begin Result := -1; end;',
    LSource) = 0,
    'legacy write_stdin must not use raw -1 unsupported stub');
end;

procedure TestLegacyPipeIoApisAreDeprecatedSourceContract;
var
  LSource: string;
begin
  LSource := LoadSourceText('src/nextpas.core.platform.process.pas');
  Check(CountSubstring(LSource,
    'deprecated ''Use platform_process_write_stdin_ex'';') = 4,
    'legacy write_stdin API should be compiler-deprecated in interface and every host implementation');
  Check(CountSubstring(LSource,
    'deprecated ''Use platform_process_read_stdout_ex'';') = 4,
    'legacy read_stdout API should be compiler-deprecated in interface and every host implementation');
  Check(CountSubstring(LSource,
    'deprecated ''Use platform_process_read_stderr_ex'';') = 4,
    'legacy read_stderr API should be compiler-deprecated in interface and every host implementation');
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

procedure TestSpawnWithEnv;
var
  LProc: TPlatformProcess;
  LArgv: array[0..1] of PAnsiChar;
  LEnv: array[0..1] of PAnsiChar;
  LResult: TPlatformProcessResult;
  LRet: Int32;
begin
  LArgv[0] := '/bin/true';
  LArgv[1] := nil;

  LEnv[0] := 'NEXTPAS_TEST_ENV_VAR=hello_env_123';
  LEnv[1] := nil;

  LRet := platform_process_spawn('/bin/true', @LArgv[0], @LEnv[0], LProc);
  Check(LRet = 0, 'spawn with env');
  platform_process_wait(LProc, LResult, 5000);
end;

procedure TestRunNilStdout;
var
  LResult: TPlatformProcessResult;
  LArgv: array[0..1] of PAnsiChar;
  LRet: Int32;
begin
  LArgv[0] := '/bin/true';
  LArgv[1] := nil;
  LRet := platform_process_run('/bin/true', @LArgv[0], nil, nil, 0, LRet, LResult.ExitCode);
  Check(LRet = 0, 'run with nil stdout');
  Check(LResult.ExitCode = 0, 'exit code 0');
end;

procedure TestRunNilStderr;
var
  LOutBuf: array[0..255] of AnsiChar;
  LOutLen, LExitCode: Int32;
  LArgv: array[0..1] of PAnsiChar;
  LRet: Int32;
begin
  LArgv[0] := '/bin/true';
  LArgv[1] := nil;
  LRet := platform_process_run('/bin/true', @LArgv[0], nil, @LOutBuf[0], 256, LOutLen, LExitCode);
  Check(LRet = 0, 'run with nil stderr');
  Check(LExitCode = 0, 'exit code 0');
end;

procedure TestRunNonZeroExit;
var
  LOutBuf: array[0..255] of AnsiChar;
  LOutLen, LExitCode: Int32;
  LArgv: array[0..1] of PAnsiChar;
  LRet: Int32;
begin
  LArgv[0] := '/bin/false';
  LArgv[1] := nil;
  LRet := platform_process_run('/bin/false', @LArgv[0], nil, @LOutBuf[0], 256, LOutLen, LExitCode);
  Check(LRet = 0, 'run succeeds');
  Check(LExitCode <> 0, 'false exits non-zero');
end;

procedure TestProcessPipeCreateAndClose;
var
  LRead, LWrite: PtrInt;
begin
  Check(platform_process_create_pipe(LRead, LWrite) = 0, 'create pipe');
  Check(LRead > 0, 'read handle valid');
  Check(LWrite > 0, 'write handle valid');
  Check(LRead <> LWrite, 'handles are different');
  platform_process_close_handle(LRead);
  platform_process_close_handle(LWrite);
end;

procedure TestOpenNullWriteMode;
var
  LHandle: PtrInt;
begin
  Check(platform_process_open_null(True, LHandle) = 0, 'open null for write');
  Check(LHandle > 0, 'handle valid');
  platform_process_close_handle(LHandle);
end;

begin
  if (ParamCount = 1) and (ParamStr(1) = OUTPUT_DRAIN_PROBE_ARG) then
  begin
    ExitCode := RunOutputDrainProbe;
    Exit;
  end;

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
  T.Test('piped ex: stdin/stdout roundtrip', @TestSpawnPipedIoEx);
  T.Test('piped ex: capture stderr', @TestSpawnPipedStderrEx);
  T.Test('piped ex: invalid buffers', @TestPipeIoExRejectsInvalidBuffers);
  T.Test('piped ex: zero length', @TestPipeIoExZeroLength);
  T.Test('legacy pipe I/O roundtrip', @TestLegacyPipeIoRoundtrip);
  T.Test('run: capture output', @TestRun);
  T.Test('run: working directory', @TestRunCwd);
  T.Test('run: discard stderr without changing exit', @TestRunDiscardsStderrWithoutChangingExit);
  T.Test('run_capture: preserve short output lengths',
    @TestRunCapturePreservesShortLengths);
  T.Test('run: reject nil output buffer with capacity',
    @TestRunRejectsNilOutputBufferWithCapacity);
  T.Test('run_capture: reject invalid output buffers',
    @TestRunCaptureRejectsInvalidBuffers);
  T.Test('run helpers: drain after output buffers fill',
    @TestRunHelpersDrainAfterBuffersFill);
  T.Test('command: EnvAdd duplicate PATH final view', @TestCommandEnvAddDuplicatePathUsesFinalResolvedView);
  T.Test('spawn_fds source: no hardcoded 1024', @TestSpawnFdsNoHardcoded1024SourceContract);
  T.Test('run_capture Windows stdout-only source contract',
    @TestWindowsRunCaptureStdoutOnlySourceContract);
  T.Test('unsupported pipe I/O stub source contract',
    @TestUnsupportedPipeIoStubSourceContract);
  T.Test('legacy pipe I/O APIs deprecated source contract',
    @TestLegacyPipeIoApisAreDeprecatedSourceContract);
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
  T.Test('spawn with env', @TestSpawnWithEnv);
  T.Test('run nil stdout', @TestRunNilStdout);
  T.Test('run nil stderr', @TestRunNilStderr);
  T.Test('run non-zero exit', @TestRunNonZeroExit);
  T.Test('pipe create and close', @TestProcessPipeCreateAndClose);
  T.Test('open null write mode', @TestOpenNullWriteMode);
  if not T.Run then Halt(1);
end.
