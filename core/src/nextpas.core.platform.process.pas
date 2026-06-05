unit nextpas.core.platform.process;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.process.base;

function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
function platform_process_spawn_piped(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; out AProc: TPlatformProcess;
  out APipes: TPlatformProcessPipes): Int32;
function platform_process_spawn_cwd(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar; out AProc: TPlatformProcess): Int32;
function platform_process_spawn_fds(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  AChildStdin, AChildStdout, AChildStderr: PtrInt;
  out AProc: TPlatformProcess;
  out AFailStage: TPlatformProcessSpawnStage): Int32;
function platform_process_spawn_piped_cwd(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  out AProc: TPlatformProcess; out APipes: TPlatformProcessPipes): Int32;
function platform_process_run(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar; AOutBuf: PAnsiChar; AOutBufLen: Int32;
  out AOutLen: Int32; out AExitCode: Int32): Int32;
function platform_process_wait(const AProc: TPlatformProcess;
  out AResult: TPlatformProcessResult): Int32;
function platform_process_try_wait(const AProc: TPlatformProcess;
  out AResult: TPlatformProcessResult): Int32;
procedure platform_process_detach(var AProc: TPlatformProcess);
function platform_process_kill(const AProc: TPlatformProcess): Int32;
function platform_process_pid(const AProc: TPlatformProcess): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
{$IF defined(NEXTPAS_LINUX) and (defined(NEXTPAS_X86_64) or defined(NEXTPAS_AARCH64))}
  {$DEFINE NEXTPAS_PROCESS_HAS_CLOSE_RANGE}
{$ENDIF}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
{$ENDIF}
{$IFDEF NEXTPAS_PROCESS_HAS_CLOSE_RANGE}
  , nextpas.core.platform.linux.modern
{$ENDIF}
  ;

const
  WNOHANG = 1;
  PLATFORM_CHILD_FD_FIRST = 3;
  PLATFORM_CHILD_FD_FALLBACK_MAX = 65536;

function ChildFdCloseMax: Int32;
var
  LOpenMax: PtrInt;
begin
  LOpenMax := sysconf(PLATFORM_SC_OPEN_MAX);
  if LOpenMax <= 3 then
    Exit(PLATFORM_CHILD_FD_FALLBACK_MAX);
  if LOpenMax > High(Int32) then
    Exit(High(Int32));
  Result := Int32(LOpenMax) - 1;
end;

procedure CloseChildFdLoop(APreserveFd: Int32);
var
  LFd: Int32;
  LLastFd: Int32;
begin
  LLastFd := ChildFdCloseMax;
  for LFd := PLATFORM_CHILD_FD_FIRST to LLastFd do
    if LFd <> APreserveFd then
      close(LFd);
end;

{$IFDEF NEXTPAS_PROCESS_HAS_CLOSE_RANGE}
function TryCloseRangeSegment(AFirst, ALast: cuint): Boolean;
begin
  if AFirst > ALast then
    Exit(True);
  Result := close_range(AFirst, ALast, 0) = 0;
end;

function TryCloseChildFdsWithCloseRange(APreserveFd: Int32): Boolean;
var
  LAfterPreserve: cuint;
begin
  if APreserveFd > PLATFORM_CHILD_FD_FIRST then
    Result := TryCloseRangeSegment(PLATFORM_CHILD_FD_FIRST,
      cuint(APreserveFd - 1))
  else
    Result := True;
  if not Result then
    Exit;

  if APreserveFd >= PLATFORM_CHILD_FD_FIRST then
    LAfterPreserve := cuint(APreserveFd) + 1
  else
    LAfterPreserve := PLATFORM_CHILD_FD_FIRST;
  Result := TryCloseRangeSegment(LAfterPreserve, High(cuint));
end;
{$ENDIF}

procedure CloseChildFdsExcept(APreserveFd: Int32);
begin
{$IFDEF NEXTPAS_PROCESS_HAS_CLOSE_RANGE}
  if TryCloseChildFdsWithCloseRange(APreserveFd) then
    Exit;
{$ENDIF}
  CloseChildFdLoop(APreserveFd);
end;

function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
var
  LPid: pid_t;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  LPid := fork;
  if LPid < 0 then
    Exit(platform_get_errno);
  if LPid = 0 then
  begin
    if AEnvp <> nil then
      execve(APath, AArgv, AEnvp)
    else
      execvp(APath, AArgv);
    halt(127);
  end;
  AProc.Pid := LPid;
  Result := 0;
end;

function platform_process_spawn_piped(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; out AProc: TPlatformProcess;
  out APipes: TPlatformProcessPipes): Int32;
var
  LPid: pid_t;
  LStdinPipe, LStdoutPipe, LStderrPipe: array[0..1] of Int32;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  FillChar(APipes, SizeOf(APipes), $FF);
  if pipe(@LStdinPipe[0]) <> 0 then Exit(platform_get_errno);
  if pipe(@LStdoutPipe[0]) <> 0 then
  begin
    close(LStdinPipe[0]); close(LStdinPipe[1]);
    Exit(platform_get_errno);
  end;
  if pipe(@LStderrPipe[0]) <> 0 then
  begin
    close(LStdinPipe[0]); close(LStdinPipe[1]);
    close(LStdoutPipe[0]); close(LStdoutPipe[1]);
    Exit(platform_get_errno);
  end;

  LPid := fork;
  if LPid < 0 then
  begin
    close(LStdinPipe[0]); close(LStdinPipe[1]);
    close(LStdoutPipe[0]); close(LStdoutPipe[1]);
    close(LStderrPipe[0]); close(LStderrPipe[1]);
    Exit(platform_get_errno);
  end;

  if LPid = 0 then
  begin
    close(LStdinPipe[1]);
    close(LStdoutPipe[0]);
    close(LStderrPipe[0]);
    dup2(LStdinPipe[0], 0);
    dup2(LStdoutPipe[1], 1);
    dup2(LStderrPipe[1], 2);
    close(LStdinPipe[0]);
    close(LStdoutPipe[1]);
    close(LStderrPipe[1]);
    if AEnvp <> nil then
      execve(APath, AArgv, AEnvp)
    else
      execve(APath, AArgv, nil);
    halt(127);
  end;

  close(LStdinPipe[0]);
  close(LStdoutPipe[1]);
  close(LStderrPipe[1]);
  AProc.Pid := LPid;
  APipes.StdinWrite := LStdinPipe[1];
  APipes.StdoutRead := LStdoutPipe[0];
  APipes.StderrRead := LStderrPipe[0];
  Result := 0;
end;

function platform_process_spawn_cwd(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar; out AProc: TPlatformProcess): Int32;
var
  LPid: pid_t;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  LPid := fork;
  if LPid < 0 then
    Exit(platform_get_errno);
  if LPid = 0 then
  begin
    if (ACwd <> nil) and (ACwd[0] <> #0) then
      if chdir(ACwd) <> 0 then
        halt(126);
    if AEnvp <> nil then
      execve(APath, AArgv, AEnvp)
    else
      execve(APath, AArgv, nil);
    halt(127);
  end;
  AProc.Pid := LPid;
  Result := 0;
end;

function platform_process_spawn_fds(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  AChildStdin, AChildStdout, AChildStderr: PtrInt;
  out AProc: TPlatformProcess;
  out AFailStage: TPlatformProcessSpawnStage): Int32;
var
  LPid: pid_t;
  LErrPipe: array[0..1] of Int32;
  LWire: TPosixSpawnWireError;
  LRead: ssize_t;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  AFailStage := pssNone;

  if pipe2(@LErrPipe[0], O_CLOEXEC) <> 0 then
  begin
    AFailStage := pssPipe;
    Exit(platform_get_errno);
  end;

  LPid := fork;
  if LPid < 0 then
  begin
    close(LErrPipe[0]);
    close(LErrPipe[1]);
    AFailStage := pssFork;
    Exit(platform_get_errno);
  end;

  if LPid = 0 then
  begin
    close(LErrPipe[0]);
    FillChar(LWire, SizeOf(LWire), 0);

    if (ACwd <> nil) and (ACwd[0] <> #0) then
      if chdir(ACwd) <> 0 then
      begin
        LWire.Stage := Ord(pssChdir);
        LWire.ErrNo := platform_get_errno;
        write(LErrPipe[1], @LWire, SizeOf(LWire));
        posix_exit(127);
      end;

    if AChildStdin >= 0 then
      if dup2(Int32(AChildStdin), 0) < 0 then
      begin
        LWire.Stage := Ord(pssDupStdin);
        LWire.ErrNo := platform_get_errno;
        write(LErrPipe[1], @LWire, SizeOf(LWire));
        posix_exit(127);
      end;
    if AChildStdout >= 0 then
      if dup2(Int32(AChildStdout), 1) < 0 then
      begin
        LWire.Stage := Ord(pssDupStdout);
        LWire.ErrNo := platform_get_errno;
        write(LErrPipe[1], @LWire, SizeOf(LWire));
        posix_exit(127);
      end;
    if AChildStderr >= 0 then
      if dup2(Int32(AChildStderr), 2) < 0 then
      begin
        LWire.Stage := Ord(pssDupStderr);
        LWire.ErrNo := platform_get_errno;
        write(LErrPipe[1], @LWire, SizeOf(LWire));
        posix_exit(127);
      end;

    CloseChildFdsExcept(LErrPipe[1]);

    if AEnvp <> nil then
      execve(APath, AArgv, AEnvp)
    else
      execvp(APath, AArgv);

    LWire.Stage := Ord(pssExec);
    LWire.ErrNo := platform_get_errno;
    write(LErrPipe[1], @LWire, SizeOf(LWire));
    posix_exit(127);
  end;

  close(LErrPipe[1]);
  FillChar(LWire, SizeOf(LWire), 0);
  LRead := read(LErrPipe[0], @LWire, SizeOf(LWire));
  close(LErrPipe[0]);

  if LRead = 0 then
  begin
    AProc.Pid := LPid;
    Result := 0;
  end
  else
  begin
    waitpid(LPid, nil, 0);
    AFailStage := TPlatformProcessSpawnStage(LWire.Stage);
    Result := LWire.ErrNo;
  end;
end;


function platform_process_spawn_piped_cwd(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  out AProc: TPlatformProcess; out APipes: TPlatformProcessPipes): Int32;
var
  LPid: pid_t;
  LStdinPipe, LStdoutPipe, LStderrPipe: array[0..1] of Int32;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  FillChar(APipes, SizeOf(APipes), $FF);
  if pipe(@LStdinPipe[0]) <> 0 then Exit(platform_get_errno);
  if pipe(@LStdoutPipe[0]) <> 0 then
  begin
    close(LStdinPipe[0]); close(LStdinPipe[1]);
    Exit(platform_get_errno);
  end;
  if pipe(@LStderrPipe[0]) <> 0 then
  begin
    close(LStdinPipe[0]); close(LStdinPipe[1]);
    close(LStdoutPipe[0]); close(LStdoutPipe[1]);
    Exit(platform_get_errno);
  end;

  LPid := fork;
  if LPid < 0 then
  begin
    close(LStdinPipe[0]); close(LStdinPipe[1]);
    close(LStdoutPipe[0]); close(LStdoutPipe[1]);
    close(LStderrPipe[0]); close(LStderrPipe[1]);
    Exit(platform_get_errno);
  end;

  if LPid = 0 then
  begin
    close(LStdinPipe[1]);
    close(LStdoutPipe[0]);
    close(LStderrPipe[0]);
    dup2(LStdinPipe[0], 0);
    dup2(LStdoutPipe[1], 1);
    dup2(LStderrPipe[1], 2);
    close(LStdinPipe[0]);
    close(LStdoutPipe[1]);
    close(LStderrPipe[1]);
    if (ACwd <> nil) and (ACwd[0] <> #0) then
      if chdir(ACwd) <> 0 then
        halt(126);
    if AEnvp <> nil then
      execve(APath, AArgv, AEnvp)
    else
      execve(APath, AArgv, nil);
    halt(127);
  end;

  close(LStdinPipe[0]);
  close(LStdoutPipe[1]);
  close(LStderrPipe[1]);
  AProc.Pid := LPid;
  APipes.StdinWrite := LStdinPipe[1];
  APipes.StdoutRead := LStdoutPipe[0];
  APipes.StderrRead := LStderrPipe[0];
  Result := 0;
end;

function DecodeStatus(AWaitStatus: Int32; out AResult: TPlatformProcessResult): Int32;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  if (AWaitStatus and $7F) = 0 then
  begin
    AResult.Status := psExited;
    AResult.ExitCode := (AWaitStatus shr 8) and $FF;
  end
  else if (AWaitStatus and $7F) <> $7F then
  begin
    AResult.Status := psSignaled;
    AResult.ExitCode := AWaitStatus and $7F;
  end
  else
    AResult.Status := psUnknown;
  Result := 0;
end;

function platform_process_wait(const AProc: TPlatformProcess;
  out AResult: TPlatformProcessResult): Int32;
var
  LStatus: Int32;
  LRet: pid_t;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LStatus := 0;
  LRet := waitpid(AProc.Pid, @LStatus, 0);
  if LRet < 0 then
    Exit(platform_get_errno);
  Result := DecodeStatus(LStatus, AResult);
end;

function platform_process_try_wait(const AProc: TPlatformProcess;
  out AResult: TPlatformProcessResult): Int32;
var
  LStatus: Int32;
  LRet: pid_t;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LStatus := 0;
  LRet := waitpid(AProc.Pid, @LStatus, WNOHANG);
  if LRet < 0 then
    Exit(platform_get_errno);
  if LRet = 0 then
  begin
    AResult.Status := psRunning;
    Exit(0);
  end;
  Result := DecodeStatus(LStatus, AResult);
end;

procedure platform_process_detach(var AProc: TPlatformProcess);
begin
  FillChar(AProc, SizeOf(AProc), 0);
end;

function platform_process_kill(const AProc: TPlatformProcess): Int32;
begin
  if kill(AProc.Pid, 9) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_process_pid(const AProc: TPlatformProcess): Int32;
begin
  Result := AProc.Pid;
end;

function platform_process_run(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar; AOutBuf: PAnsiChar; AOutBufLen: Int32;
  out AOutLen: Int32; out AExitCode: Int32): Int32;
var
  LProc: TPlatformProcess;
  LPipes: TPlatformProcessPipes;
  LResult: TPlatformProcessResult;
  LN: PtrInt;
  LTotal: Int32;
begin
  AOutLen := 0;
  AExitCode := -1;
  Result := platform_process_spawn_piped_cwd(APath, AArgv, nil, ACwd, LProc, LPipes);
  if Result <> 0 then
    Exit;
  close(LPipes.StdinWrite);
  close(LPipes.StderrRead);
  LTotal := 0;
  repeat
    LN := read(LPipes.StdoutRead, @AOutBuf[LTotal], AOutBufLen - LTotal);
    if LN > 0 then
      Inc(LTotal, Int32(LN));
  until (LN <= 0) or (LTotal >= AOutBufLen);
  close(LPipes.StdoutRead);
  if LTotal < AOutBufLen then
    AOutBuf[LTotal] := #0;
  AOutLen := LTotal;
  Result := platform_process_wait(LProc, LResult);
  if Result = 0 then
    AExitCode := LResult.ExitCode;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi,
  nextpas.core.platform.windows.utf16;

function CreateWindowsProcess(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar; AInheritHandles: Boolean;
  ACreationFlags: DWORD; var AStartupInfo: STARTUPINFOW;
  out AProcessInfo: PROCESS_INFORMATION): Int32;
var
  LCmd: UnicodeString;
  LCwd: UnicodeString;
  LEnvBlock: UnicodeString;
  LCwdPtr: PWideChar;
  LEnvPtr: Pointer;
  LCreationFlags: DWORD;
begin
  FillChar(AProcessInfo, SizeOf(AProcessInfo), 0);
  if not platform_windows_argv_to_command_line(APath, AArgv, LCmd) then
    Exit(Int32(ERROR_INVALID_NAME));

  LCwdPtr := nil;
  if ACwd <> nil then
  begin
    if not platform_windows_utf8_to_wide_checked(ACwd, LCwd) then
      Exit(Int32(ERROR_INVALID_NAME));
    LCwdPtr := PWideChar(LCwd);
  end;

  LEnvPtr := nil;
  if AEnvp <> nil then
  begin
    if not platform_windows_envp_to_wide_block(AEnvp, LEnvBlock) then
      Exit(Int32(ERROR_INVALID_NAME));
    LEnvPtr := PWideChar(LEnvBlock);
  end;

  LCreationFlags := ACreationFlags;
  if AEnvp <> nil then
    LCreationFlags := LCreationFlags or CREATE_UNICODE_ENVIRONMENT;
  if not CreateProcessW(nil, PWideChar(LCmd), nil, nil, AInheritHandles,
    LCreationFlags, LEnvPtr, LCwdPtr, @AStartupInfo,
    @AProcessInfo) then
    Exit(Int32(GetLastError));
  Result := 0;
end;

function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
var
  LSI: STARTUPINFOW;
  LPI: PROCESS_INFORMATION;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  FillChar(LSI, SizeOf(LSI), 0);
  LSI.cb := SizeOf(LSI);
  Result := CreateWindowsProcess(APath, AArgv, AEnvp, nil, False, 0, LSI, LPI);
  if Result <> 0 then
    Exit;
  AProc.ProcessHandle := PtrUInt(LPI.hProcess);
  AProc.ThreadHandle := PtrUInt(LPI.hThread);
  AProc.Pid := LPI.dwProcessId;
  CloseHandle(HANDLE(AProc.ThreadHandle));
  AProc.ThreadHandle := 0;
  Result := 0;
end;

function platform_process_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult): Int32;
var LExitCode: DWORD;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  if WaitForSingleObject(HANDLE(AProc.ProcessHandle), $FFFFFFFF) <> 0 then Exit(Int32(GetLastError));
  LExitCode := 0; if not GetExitCodeProcess(HANDLE(AProc.ProcessHandle), @LExitCode) then Exit(Int32(GetLastError));
  AResult.Status := psExited; AResult.ExitCode := Int32(LExitCode); CloseHandle(HANDLE(AProc.ProcessHandle)); Result := 0;
end;

function platform_process_try_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult): Int32;
var LExitCode, LWait: DWORD;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LWait := WaitForSingleObject(HANDLE(AProc.ProcessHandle), 0);
  if LWait = $00000102 then begin AResult.Status := psRunning; Exit(0); end;
  if LWait <> 0 then Exit(Int32(GetLastError));
  LExitCode := 0; GetExitCodeProcess(HANDLE(AProc.ProcessHandle), @LExitCode);
  AResult.Status := psExited; AResult.ExitCode := Int32(LExitCode); CloseHandle(HANDLE(AProc.ProcessHandle)); Result := 0;
end;

procedure platform_process_detach(var AProc: TPlatformProcess);
begin
  if AProc.ProcessHandle <> 0 then
    CloseHandle(HANDLE(AProc.ProcessHandle));
  AProc.ProcessHandle := 0;
  AProc.ThreadHandle := 0;
end;

function platform_process_kill(const AProc: TPlatformProcess): Int32;
begin if TerminateProcess(HANDLE(AProc.ProcessHandle), 1) then Result := 0 else Result := Int32(GetLastError); end;

function platform_process_pid(const AProc: TPlatformProcess): Int32;
begin Result := Int32(AProc.Pid); end;

function platform_process_spawn_piped(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; out AProc: TPlatformProcess;
  out APipes: TPlatformProcessPipes): Int32;
var
  LSI: STARTUPINFOW;
  LPI: PROCESS_INFORMATION;
  LStdinRd, LStdinWr, LStdoutRd, LStdoutWr, LStderrRd, LStderrWr: HANDLE;
  LSA: SECURITY_ATTRIBUTES;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  FillChar(APipes, SizeOf(APipes), $FF);
  FillChar(LSA, SizeOf(LSA), 0);
  LSA.nLength := SizeOf(LSA);
  LSA.bInheritHandle := True;

  if not CreatePipe(@LStdinRd, @LStdinWr, @LSA, 0) then Exit(Int32(GetLastError));
  if not CreatePipe(@LStdoutRd, @LStdoutWr, @LSA, 0) then
  begin CloseHandle(LStdinRd); CloseHandle(LStdinWr); Exit(Int32(GetLastError)); end;
  if not CreatePipe(@LStderrRd, @LStderrWr, @LSA, 0) then
  begin CloseHandle(LStdinRd); CloseHandle(LStdinWr); CloseHandle(LStdoutRd); CloseHandle(LStdoutWr); Exit(Int32(GetLastError)); end;

  SetHandleInformation(LStdinWr, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(LStdoutRd, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(LStderrRd, HANDLE_FLAG_INHERIT, 0);

  FillChar(LSI, SizeOf(LSI), 0);
  LSI.cb := SizeOf(LSI);
  LSI.dwFlags := STARTF_USESTDHANDLES;
  LSI.hStdInput := LStdinRd;
  LSI.hStdOutput := LStdoutWr;
  LSI.hStdError := LStderrWr;

  Result := CreateWindowsProcess(APath, AArgv, AEnvp, nil, True, 0, LSI, LPI);
  if Result <> 0 then
  begin
    CloseHandle(LStdinRd); CloseHandle(LStdinWr);
    CloseHandle(LStdoutRd); CloseHandle(LStdoutWr);
    CloseHandle(LStderrRd); CloseHandle(LStderrWr);
    Exit;
  end;

  CloseHandle(LStdinRd);
  CloseHandle(LStdoutWr);
  CloseHandle(LStderrWr);
  CloseHandle(HANDLE(LPI.hThread));

  AProc.ProcessHandle := PtrUInt(LPI.hProcess);
  AProc.Pid := LPI.dwProcessId;
  APipes.StdinWrite := PtrInt(PtrUInt(LStdinWr));
  APipes.StdoutRead := PtrInt(PtrUInt(LStdoutRd));
  APipes.StderrRead := PtrInt(PtrUInt(LStderrRd));
  Result := 0;
end;

function platform_process_spawn_cwd(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar; out AProc: TPlatformProcess): Int32;
var
  LSI: STARTUPINFOW;
  LPI: PROCESS_INFORMATION;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  FillChar(LSI, SizeOf(LSI), 0);
  LSI.cb := SizeOf(LSI);
  Result := CreateWindowsProcess(APath, AArgv, AEnvp, ACwd, False, 0, LSI, LPI);
  if Result <> 0 then
    Exit;
  AProc.ProcessHandle := PtrUInt(LPI.hProcess);
  AProc.Pid := LPI.dwProcessId;
  CloseHandle(HANDLE(LPI.hThread));
  Result := 0;
end;

function platform_process_spawn_fds(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  AChildStdin, AChildStdout, AChildStderr: PtrInt;
  out AProc: TPlatformProcess;
  out AFailStage: TPlatformProcessSpawnStage): Int32;
var
  LSI: STARTUPINFOW;
  LPI: PROCESS_INFORMATION;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  AFailStage := pssNone;
  FillChar(LSI, SizeOf(LSI), 0);
  LSI.cb := SizeOf(LSI);
  LSI.dwFlags := STARTF_USESTDHANDLES;
  if AChildStdin >= 0 then
    LSI.hStdInput := HANDLE(PtrUInt(AChildStdin))
  else
    LSI.hStdInput := GetStdHandle(STD_INPUT_HANDLE);
  if AChildStdout >= 0 then
    LSI.hStdOutput := HANDLE(PtrUInt(AChildStdout))
  else
    LSI.hStdOutput := GetStdHandle(STD_OUTPUT_HANDLE);
  if AChildStderr >= 0 then
    LSI.hStdError := HANDLE(PtrUInt(AChildStderr))
  else
    LSI.hStdError := GetStdHandle(STD_ERROR_HANDLE);

  Result := CreateWindowsProcess(APath, AArgv, AEnvp, ACwd, True, 0, LSI, LPI);
  if Result <> 0 then
  begin
    AFailStage := pssExec;
    Exit;
  end;
  AProc.ProcessHandle := PtrUInt(LPI.hProcess);
  AProc.ThreadHandle := PtrUInt(LPI.hThread);
  AProc.Pid := LPI.dwProcessId;
  CloseHandle(HANDLE(AProc.ThreadHandle));
  AProc.ThreadHandle := 0;
  Result := 0;
end;

function platform_process_spawn_piped_cwd(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  out AProc: TPlatformProcess; out APipes: TPlatformProcessPipes): Int32;
var
  LSI: STARTUPINFOW;
  LPI: PROCESS_INFORMATION;
  LStdinRd, LStdinWr, LStdoutRd, LStdoutWr, LStderrRd, LStderrWr: HANDLE;
  LSA: SECURITY_ATTRIBUTES;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  FillChar(APipes, SizeOf(APipes), $FF);
  FillChar(LSA, SizeOf(LSA), 0);
  LSA.nLength := SizeOf(LSA);
  LSA.bInheritHandle := True;

  if not CreatePipe(@LStdinRd, @LStdinWr, @LSA, 0) then Exit(Int32(GetLastError));
  if not CreatePipe(@LStdoutRd, @LStdoutWr, @LSA, 0) then
  begin CloseHandle(LStdinRd); CloseHandle(LStdinWr); Exit(Int32(GetLastError)); end;
  if not CreatePipe(@LStderrRd, @LStderrWr, @LSA, 0) then
  begin CloseHandle(LStdinRd); CloseHandle(LStdinWr); CloseHandle(LStdoutRd); CloseHandle(LStdoutWr); Exit(Int32(GetLastError)); end;

  SetHandleInformation(LStdinWr, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(LStdoutRd, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(LStderrRd, HANDLE_FLAG_INHERIT, 0);

  FillChar(LSI, SizeOf(LSI), 0);
  LSI.cb := SizeOf(LSI);
  LSI.dwFlags := STARTF_USESTDHANDLES;
  LSI.hStdInput := LStdinRd;
  LSI.hStdOutput := LStdoutWr;
  LSI.hStdError := LStderrWr;

  Result := CreateWindowsProcess(APath, AArgv, AEnvp, ACwd, True, 0, LSI, LPI);
  if Result <> 0 then
  begin
    CloseHandle(LStdinRd); CloseHandle(LStdinWr);
    CloseHandle(LStdoutRd); CloseHandle(LStdoutWr);
    CloseHandle(LStderrRd); CloseHandle(LStderrWr);
    Exit;
  end;

  CloseHandle(LStdinRd);
  CloseHandle(LStdoutWr);
  CloseHandle(LStderrWr);
  CloseHandle(HANDLE(LPI.hThread));

  AProc.ProcessHandle := PtrUInt(LPI.hProcess);
  AProc.Pid := LPI.dwProcessId;
  APipes.StdinWrite := PtrInt(PtrUInt(LStdinWr));
  APipes.StdoutRead := PtrInt(PtrUInt(LStdoutRd));
  APipes.StderrRead := PtrInt(PtrUInt(LStderrRd));
  Result := 0;
end;

function platform_process_run(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar; AOutBuf: PAnsiChar; AOutBufLen: Int32;
  out AOutLen: Int32; out AExitCode: Int32): Int32;
var
  LProc: TPlatformProcess;
  LPipes: TPlatformProcessPipes;
  LResult: TPlatformProcessResult;
  LRead: DWORD;
  LTotal: Int32;
begin
  AOutLen := 0;
  AExitCode := -1;
  Result := platform_process_spawn_piped_cwd(APath, AArgv, nil, ACwd, LProc, LPipes);
  if Result <> 0 then
    Exit;
  CloseHandle(HANDLE(PtrUInt(LPipes.StdinWrite)));
  CloseHandle(HANDLE(PtrUInt(LPipes.StderrRead)));
  LTotal := 0;
  repeat
    LRead := 0;
    if not ReadFile(HANDLE(PtrUInt(LPipes.StdoutRead)), @AOutBuf[LTotal],
      DWORD(AOutBufLen - LTotal), @LRead, nil) then
      Break;
    if LRead = 0 then Break;
    Inc(LTotal, Int32(LRead));
  until LTotal >= AOutBufLen;
  CloseHandle(HANDLE(PtrUInt(LPipes.StdoutRead)));
  if LTotal < AOutBufLen then
    AOutBuf[LTotal] := #0;
  AOutLen := LTotal;
  Result := platform_process_wait(LProc, LResult);
  if Result = 0 then
    AExitCode := LResult.ExitCode;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
begin FillChar(AProc, SizeOf(AProc), 0); Result := -1; end;
function platform_process_spawn_piped(const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; out AProc: TPlatformProcess; out APipes: TPlatformProcessPipes): Int32;
begin FillChar(AProc, SizeOf(AProc), 0); FillChar(APipes, SizeOf(APipes), $FF); Result := -1; end;
function platform_process_spawn_cwd(const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; const ACwd: PAnsiChar; out AProc: TPlatformProcess): Int32;
begin FillChar(AProc, SizeOf(AProc), 0); Result := -1; end;
function platform_process_spawn_piped_cwd(const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; const ACwd: PAnsiChar; out AProc: TPlatformProcess; out APipes: TPlatformProcessPipes): Int32;
begin FillChar(AProc, SizeOf(AProc), 0); FillChar(APipes, SizeOf(APipes), $FF); Result := -1; end;
function platform_process_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := -1; end;
function platform_process_try_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := -1; end;
procedure platform_process_detach(var AProc: TPlatformProcess);
begin FillChar(AProc, SizeOf(AProc), 0); end;
function platform_process_kill(const AProc: TPlatformProcess): Int32;
begin Result := -1; end;
function platform_process_pid(const AProc: TPlatformProcess): Int32;
begin Result := -1; end;
function platform_process_run(const APath: PAnsiChar; AArgv: PPAnsiChar; const ACwd: PAnsiChar; AOutBuf: PAnsiChar; AOutBufLen: Int32; out AOutLen: Int32; out AExitCode: Int32): Int32;
begin AOutLen := 0; AExitCode := -1; Result := -1; end;
{$ENDIF}

end.
