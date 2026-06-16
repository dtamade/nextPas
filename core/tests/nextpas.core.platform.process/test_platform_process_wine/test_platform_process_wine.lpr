program test_platform_process_wine;

{ Real Windows runtime evidence only when compiled and run on a Windows host. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.process.base,
  nextpas.core.platform.process
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.base,
    nextpas.core.platform.windows.ffi
  {$ENDIF}
  ;

var
  T: TTestRunner;

{$IFDEF NEXTPAS_WINDOWS}

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
    Check(SetHandleInformation(HANDLE(PtrUInt(AStdinWrite)),
      HANDLE_FLAG_INHERIT, 0), 'stdin parent handle non-inheritable');
    Check(SetHandleInformation(HANDLE(PtrUInt(AStdoutRead)),
      HANDLE_FLAG_INHERIT, 0), 'stdout parent handle non-inheritable');
    Check(SetHandleInformation(HANDLE(PtrUInt(AStderrRead)),
      HANDLE_FLAG_INHERIT, 0), 'stderr parent handle non-inheritable');
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

{ 1. Spawn cmd.exe and wait for it to exit with code 0 }
procedure TestSpawnAndWait;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
begin
  LArgv[0] := 'cmd.exe';
  LArgv[1] := '/c';
  LArgv[2] := 'echo hello_wine';
  LArgv[3] := nil;
  Check(platform_process_spawn('cmd.exe', @LArgv[0], nil, P) = 0, 'spawn cmd.exe');
  Check(platform_process_wait(P, R) = 0, 'wait');
  Check(R.Status = psExited, 'exited');
  Check(R.ExitCode = 0, 'exit code 0');
end;

{ 2. PID must be a reasonable positive value }
procedure TestPid;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
begin
  LArgv[0] := 'cmd.exe';
  LArgv[1] := '/c';
  LArgv[2] := 'echo hello_wine';
  LArgv[3] := nil;
  Check(platform_process_spawn('cmd.exe', @LArgv[0], nil, P) = 0, 'spawn cmd.exe');
  Check(platform_process_pid(P) > 0, 'pid > 0');
  platform_process_wait(P, R);
end;

{ 3. Spawn with pipes, read stdout, verify "hello_wine" }
procedure TestSpawnPipedStdout;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..255] of AnsiChar;
  LRead: DWORD;
  LTotal: Int32;
  LStdinWrite: PtrInt;
  LStdoutRead: PtrInt;
  LStderrRead: PtrInt;
begin
  LArgv[0] := 'cmd.exe';
  LArgv[1] := '/c';
  LArgv[2] := 'echo hello_wine';
  LArgv[3] := nil;
  SpawnWithPipes('cmd.exe', @LArgv[0], P, LStdinWrite, LStdoutRead, LStderrRead);
  Check(LStdoutRead >= 0, 'stdout pipe valid');

  { Close unused write end of stdin pipe }
  platform_process_close_handle(LStdinWrite);

  LTotal := 0;
  FillChar(LBuf, SizeOf(LBuf), 0);
  while True do
  begin
    if not ReadFile(HANDLE(PtrUInt(LStdoutRead)), @LBuf[LTotal],
      DWORD(SizeOf(LBuf) - LTotal - 1), @LRead, nil) then
      Break;
    if LRead = 0 then Break;
    Inc(LTotal, Int32(LRead));
  end;
  LBuf[LTotal] := #0;

  Check(LTotal > 0, 'read > 0 bytes from stdout');
  Check(Pos('hello_wine', string(LBuf)) > 0, 'stdout contains hello_wine');

  { Close remaining pipe handles }
  platform_process_close_handle(LStdoutRead);
  platform_process_close_handle(LStderrRead);

  platform_process_wait(P, R);
  Check(R.ExitCode = 0, 'exit 0');
end;

{ 4. Run + capture output, verify content }
procedure TestRun;
var
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..255] of AnsiChar;
  LOutLen, LExitCode: Int32;
begin
  LArgv[0] := 'cmd.exe';
  LArgv[1] := '/c';
  LArgv[2] := 'echo hello_wine';
  LArgv[3] := nil;
  FillChar(LBuf, SizeOf(LBuf), 0);
  Check(platform_process_run('cmd.exe', @LArgv[0], nil,
    @LBuf[0], 256, LOutLen, LExitCode) = 0, 'run ok');
  Check(LExitCode = 0, 'exit 0');
  Check(LOutLen > 0, 'output length > 0');
  Check(Pos('hello_wine', string(LBuf)) > 0, 'output contains hello_wine');
end;

{ 5. TryWait on a running process, then Wait }
procedure TestTryWait;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
begin
  LArgv[0] := 'cmd.exe';
  LArgv[1] := '/c';
  LArgv[2] := 'ping -n 6 127.0.0.1';
  LArgv[3] := nil;
  Check(platform_process_spawn('cmd.exe', @LArgv[0], nil, P) = 0, 'spawn');
  { TryWait may return psRunning or psExited depending on timing }
  Check(platform_process_try_wait(P, R) = 0, 'try_wait');
  { Now wait for the process to finish }
  platform_process_wait(P, R);
  Check(R.Status = psExited, 'exited after wait');
end;

{ 6. Kill a running process, verify killed }
procedure TestKill;
var
  P: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
begin
  LArgv[0] := 'cmd.exe';
  LArgv[1] := '/c';
  LArgv[2] := 'ping -n 10 127.0.0.1';
  LArgv[3] := nil;
  Check(platform_process_spawn('cmd.exe', @LArgv[0], nil, P) = 0, 'spawn');
  Check(platform_process_kill(P) = 0, 'kill');
  Check(platform_process_wait(P, R) = 0, 'wait after kill');
  { Windows TerminateProcess sets exit code to 1; no signaled/exit distinction on Windows }
  Check(R.ExitCode = 1, 'exit code 1 from TerminateProcess');
end;

{ 7. Detach a process without crashing }
procedure TestDetach;
var
  P: TPlatformProcess;
  LArgv: array[0..3] of PAnsiChar;
begin
  LArgv[0] := 'cmd.exe';
  LArgv[1] := '/c';
  LArgv[2] := 'echo detached';
  LArgv[3] := nil;
  Check(platform_process_spawn('cmd.exe', @LArgv[0], nil, P) = 0, 'spawn');
  platform_process_detach(P);
  { After detach, the process handle is closed; nothing should crash }
  Check(True, 'detach completed without crash');
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.process.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Run('spawn + wait (exit 0)', @TestSpawnAndWait);
  T.Run('pid returns reasonable value', @TestPid);
  T.Run('piped: capture stdout', @TestSpawnPipedStdout);
  T.Run('run: capture output', @TestRun);
  T.Run('try_wait then wait', @TestTryWait);
  T.Run('kill', @TestKill);
  T.Run('detach', @TestDetach);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.
