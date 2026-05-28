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
function platform_process_kill(const AProc: TPlatformProcess): Int32;
function platform_process_pid(const AProc: TPlatformProcess): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
{$ENDIF}
  ;

const
  WNOHANG = 1;

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
      execve(APath, AArgv, nil);
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
  nextpas.core.platform.windows.ffi;

function BuildCmdLine(const APath: PAnsiChar; AArgv: PPAnsiChar): AnsiString;
var LP: PPAnsiChar;
begin
  Result := APath;
  if AArgv <> nil then begin LP := AArgv; Inc(LP); while LP^ <> nil do begin Result := Result + ' ' + LP^; Inc(LP); end; end;
end;

function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
var LSI: STARTUPINFOA; LPI: PROCESS_INFORMATION; LCmd: AnsiString;
begin
  FillChar(AProc, SizeOf(AProc), 0); FillChar(LSI, SizeOf(LSI), 0); FillChar(LPI, SizeOf(LPI), 0);
  LSI.cb := SizeOf(LSI); LCmd := BuildCmdLine(APath, AArgv);
  if not CreateProcessA(nil, @LCmd[1], nil, nil, False, 0, nil, nil, @LSI, @LPI) then Exit(Int32(GetLastError));
  AProc.ProcessHandle := PtrUInt(LPI.hProcess); AProc.ThreadHandle := PtrUInt(LPI.hThread);
  AProc.Pid := LPI.dwProcessId; CloseHandle(HANDLE(AProc.ThreadHandle)); AProc.ThreadHandle := 0; Result := 0;
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

function platform_process_kill(const AProc: TPlatformProcess): Int32;
begin if TerminateProcess(HANDLE(AProc.ProcessHandle), 1) then Result := 0 else Result := Int32(GetLastError); end;

function platform_process_pid(const AProc: TPlatformProcess): Int32;
begin Result := Int32(AProc.Pid); end;

function platform_process_spawn_piped(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; out AProc: TPlatformProcess;
  out APipes: TPlatformProcessPipes): Int32;
var
  LSI: STARTUPINFOA;
  LPI: PROCESS_INFORMATION;
  LCmd: AnsiString;
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
  FillChar(LPI, SizeOf(LPI), 0);
  LCmd := BuildCmdLine(APath, AArgv);

  if not CreateProcessA(nil, @LCmd[1], nil, nil, True, 0, nil, nil, @LSI, @LPI) then
  begin
    CloseHandle(LStdinRd); CloseHandle(LStdinWr);
    CloseHandle(LStdoutRd); CloseHandle(LStdoutWr);
    CloseHandle(LStderrRd); CloseHandle(LStderrWr);
    Exit(Int32(GetLastError));
  end;

  CloseHandle(LStdinRd);
  CloseHandle(LStdoutWr);
  CloseHandle(LStderrWr);
  CloseHandle(HANDLE(LPI.hThread));

  AProc.ProcessHandle := PtrUInt(LPI.hProcess);
  AProc.Pid := LPI.dwProcessId;
  APipes.StdinWrite := Int32(PtrUInt(LStdinWr));
  APipes.StdoutRead := Int32(PtrUInt(LStdoutRd));
  APipes.StderrRead := Int32(PtrUInt(LStderrRd));
  Result := 0;
end;

function platform_process_spawn_cwd(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar; out AProc: TPlatformProcess): Int32;
var LSI: STARTUPINFOA; LPI: PROCESS_INFORMATION; LCmd: AnsiString;
begin
  FillChar(AProc, SizeOf(AProc), 0); FillChar(LSI, SizeOf(LSI), 0); FillChar(LPI, SizeOf(LPI), 0);
  LSI.cb := SizeOf(LSI); LCmd := BuildCmdLine(APath, AArgv);
  if not CreateProcessA(nil, @LCmd[1], nil, nil, False, 0, nil, ACwd, @LSI, @LPI) then Exit(Int32(GetLastError));
  AProc.ProcessHandle := PtrUInt(LPI.hProcess);
  AProc.Pid := LPI.dwProcessId; CloseHandle(HANDLE(LPI.hThread)); Result := 0;
end;

function platform_process_spawn_piped_cwd(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  out AProc: TPlatformProcess; out APipes: TPlatformProcessPipes): Int32;
var
  LSI: STARTUPINFOA;
  LPI: PROCESS_INFORMATION;
  LCmd: AnsiString;
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
  FillChar(LPI, SizeOf(LPI), 0);
  LCmd := BuildCmdLine(APath, AArgv);

  if not CreateProcessA(nil, @LCmd[1], nil, nil, True, 0, nil, ACwd, @LSI, @LPI) then
  begin
    CloseHandle(LStdinRd); CloseHandle(LStdinWr);
    CloseHandle(LStdoutRd); CloseHandle(LStdoutWr);
    CloseHandle(LStderrRd); CloseHandle(LStderrWr);
    Exit(Int32(GetLastError));
  end;

  CloseHandle(LStdinRd);
  CloseHandle(LStdoutWr);
  CloseHandle(LStderrWr);
  CloseHandle(HANDLE(LPI.hThread));

  AProc.ProcessHandle := PtrUInt(LPI.hProcess);
  AProc.Pid := LPI.dwProcessId;
  APipes.StdinWrite := Int32(PtrUInt(LStdinWr));
  APipes.StdoutRead := Int32(PtrUInt(LStdoutRd));
  APipes.StderrRead := Int32(PtrUInt(LStderrRd));
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
function platform_process_kill(const AProc: TPlatformProcess): Int32;
begin Result := -1; end;
function platform_process_pid(const AProc: TPlatformProcess): Int32;
begin Result := -1; end;
function platform_process_run(const APath: PAnsiChar; AArgv: PPAnsiChar; const ACwd: PAnsiChar; AOutBuf: PAnsiChar; AOutBufLen: Int32; out AOutLen: Int32; out AExitCode: Int32): Int32;
begin AOutLen := 0; AExitCode := -1; Result := -1; end;
{$ENDIF}

end.
