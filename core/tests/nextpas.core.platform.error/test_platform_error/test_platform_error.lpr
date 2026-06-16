program test_platform_error;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.error,
  nextpas.core.platform.process.base,
  nextpas.core.platform.process,
  nextpas.core.platform.posix.ffi,
  nextpas.core.testing;

var
  T: TTestRunner;

function StrContains(const AHaystack, ANeedle: PAnsiChar): Boolean;
var
  I, J, HLen, NLen: Int32;
begin
  HLen := 0;
  while AHaystack[HLen] <> #0 do Inc(HLen);
  NLen := 0;
  while ANeedle[NLen] <> #0 do Inc(NLen);
  if NLen = 0 then Exit(True);
  if NLen > HLen then Exit(False);
  for I := 0 to HLen - NLen do
  begin
    J := 0;
    while (J < NLen) and (AHaystack[I + J] = ANeedle[J]) do
      Inc(J);
    if J = NLen then Exit(True);
  end;
  Result := False;
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

procedure TestENOENT;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(2, @Buf[0], 256);
  Check(R > 0, 'ENOENT returns length > 0');
  Check(StrContains(@Buf[0], 'o such file'), 'contains "o such file"');
end;

procedure TestEACCES;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(13, @Buf[0], 256);
  Check(R > 0, 'EACCES returns length > 0');
  Check(StrContains(@Buf[0], 'ermission'), 'contains "ermission"');
end;

procedure TestZero;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(0, @Buf[0], 256);
  Check(R >= 0, 'code 0 returns >= 0');
  Check(Buf[0] <> #0, 'non-empty string');
end;

procedure TestUnknown;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(9999, @Buf[0], 256);
  Check(R > 0, 'unknown code returns > 0');
  Check(Buf[0] <> #0, 'non-empty');
end;

procedure TestSmallBuffer;
var
  Buf: array[0..3] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(2, @Buf[0], 4);
  Check(R >= 0, 'small buffer does not crash');
  Check(Buf[3] = #0, 'null terminated');
end;

procedure TestFatalExists;
var
  P: Pointer;
begin
  P := @platform_fatal;
  Check(P <> nil, 'platform_fatal linked');
  P := @platform_fatal_code;
  Check(P <> nil, 'platform_fatal_code linked');
end;

procedure TestFatalBehavior;
var
  Proc: TPlatformProcess;
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
  LArgv[2] := 'echo "fatal: test message" >&2; exit 1';
  LArgv[3] := nil;
  SpawnWithPipes('/bin/sh', @LArgv[0], Proc, LStdinWrite, LStdoutRead, LStderrRead);
  platform_process_close_handle(LStdinWrite);
  platform_process_close_handle(LStdoutRead);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := nextpas.core.platform.posix.ffi.read(LStderrRead, @LBuf[0], 256);
  Check(LRead > 0, 'stderr has output');
  Check(LBuf[0] = 'f', 'starts with f');
  Check(LBuf[1] = 'a', 'second char a');
  platform_process_close_handle(LStderrRead);
  platform_process_wait(Proc, R);
  Check(R.ExitCode = 1, 'exit code 1');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.error');
  T.Run('ENOENT message', @TestENOENT);
  T.Run('EACCES message', @TestEACCES);
  T.Run('code 0 (Success)', @TestZero);
  T.Run('unknown error code', @TestUnknown);
  T.Run('small buffer truncation', @TestSmallBuffer);
  T.Run('fatal API exists', @TestFatalExists);
  T.Run('fatal behavior (via subprocess)', @TestFatalBehavior);
  T.Summary;
end.
