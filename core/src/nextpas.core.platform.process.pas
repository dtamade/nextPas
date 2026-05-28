unit nextpas.core.platform.process;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.process.base;

function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
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
    Exit(-1);
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
    Exit(-1);
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
    Exit(-1);
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
    Result := -1;
end;

function platform_process_pid(const AProc: TPlatformProcess): Int32;
begin
  Result := AProc.Pid;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
begin FillChar(AProc, SizeOf(AProc), 0); Result := -1; end;
function platform_process_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := -1; end;
function platform_process_try_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := -1; end;
function platform_process_kill(const AProc: TPlatformProcess): Int32;
begin Result := -1; end;
function platform_process_pid(const AProc: TPlatformProcess): Int32;
begin Result := -1; end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
begin FillChar(AProc, SizeOf(AProc), 0); Result := -1; end;
function platform_process_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := -1; end;
function platform_process_try_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := -1; end;
function platform_process_kill(const AProc: TPlatformProcess): Int32;
begin Result := -1; end;
function platform_process_pid(const AProc: TPlatformProcess): Int32;
begin Result := -1; end;
{$ENDIF}

end.
