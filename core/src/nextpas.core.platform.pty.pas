unit nextpas.core.platform.pty;
{**
 * @desc 跨平台伪终端：打开 PTY 对、spawn 子进程、resize、关闭。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.pty.base;

function platform_pty_open(const ASize: TPlatformPtySize;
  out APty: TPlatformPty): Int32;

function platform_pty_spawn(var APty: TPlatformPty;
  const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar;
  const ACwd: PAnsiChar; out APid: Int32;
  out AFailStage: TPlatformPtySpawnStage): Int32;

function platform_pty_resize(var APty: TPlatformPty;
  const ASize: TPlatformPtySize): Int32;

function platform_pty_close(var APty: TPlatformPty): Int32;

function platform_pty_master_fd(const APty: TPlatformPty): PtrInt;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.error
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  , nextpas.core.platform.linux.ffi
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.base
  , nextpas.core.platform.darwin.ffi
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  , nextpas.core.platform.freebsd.base
  , nextpas.core.platform.freebsd.ffi
{$ENDIF}
  ;

type
  TPlatformPtySpawnWireError = packed record
    Stage: UInt8;
    Reserved: array[0..2] of UInt8;
    ErrNo: Int32;
  end;

procedure WriteSpawnError(AFd: Int32; AStage: TPlatformPtySpawnStage; AErrNo: Int32);
var
  LWire: TPlatformPtySpawnWireError;
begin
  FillChar(LWire, SizeOf(LWire), 0);
  LWire.Stage := Ord(AStage);
  LWire.ErrNo := AErrNo;
  write(AFd, @LWire, SizeOf(LWire));
end;

function platform_pty_open(const ASize: TPlatformPtySize;
  out APty: TPlatformPty): Int32;
var
  LWs: winsize;
  LMaster, LSlave: cint;
begin
  FillChar(APty, SizeOf(APty), 0);
  APty.FMasterFd := -1;
  APty.FSlaveFd := -1;

  LWs.ws_col := ASize.FCols;
  LWs.ws_row := ASize.FRows;
  LWs.ws_xpixel := ASize.FXPixel;
  LWs.ws_ypixel := ASize.FYPixel;

  if openpty(@LMaster, @LSlave, nil, nil, @LWs) <> 0 then
    Exit(platform_get_errno);

  APty.FMasterFd := LMaster;
  APty.FSlaveFd := LSlave;
  Result := 0;
end;

function platform_pty_spawn(var APty: TPlatformPty;
  const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar;
  const ACwd: PAnsiChar; out APid: Int32;
  out AFailStage: TPlatformPtySpawnStage): Int32;
var
  LErrPipe: array[0..1] of Int32;
  LPid: pid_t;
  LWire: TPlatformPtySpawnWireError;
  LN: ssize_t;
  LErrno: Int32;
begin
  APid := -1;
  AFailStage := ptssNone;

  if pipe2(@LErrPipe[0], O_CLOEXEC) <> 0 then
  begin
    AFailStage := ptssPipe;
    Exit(platform_get_errno);
  end;

  LPid := fork;
  if LPid < 0 then
  begin
    AFailStage := ptssFork;
    LErrno := platform_get_errno;
    close(LErrPipe[0]);
    close(LErrPipe[1]);
    Exit(LErrno);
  end;

  if LPid = 0 then
  begin
    { child }
    close(LErrPipe[0]);

    if setsid < 0 then
    begin
      LErrno := platform_get_errno;
      WriteSpawnError(LErrPipe[1], ptssSetsid, LErrno);
      posix_exit(127);
    end;

    if ioctl(APty.FSlaveFd, TIOCSCTTY, Pointer(0)) < 0 then
    begin
      LErrno := platform_get_errno;
      WriteSpawnError(LErrPipe[1], ptssTiocsctty, LErrno);
      posix_exit(127);
    end;

    if dup2(APty.FSlaveFd, 0) < 0 then
    begin
      LErrno := platform_get_errno;
      WriteSpawnError(LErrPipe[1], ptssDup, LErrno);
      posix_exit(127);
    end;
    if dup2(APty.FSlaveFd, 1) < 0 then
    begin
      LErrno := platform_get_errno;
      WriteSpawnError(LErrPipe[1], ptssDup, LErrno);
      posix_exit(127);
    end;
    if dup2(APty.FSlaveFd, 2) < 0 then
    begin
      LErrno := platform_get_errno;
      WriteSpawnError(LErrPipe[1], ptssDup, LErrno);
      posix_exit(127);
    end;
    if APty.FSlaveFd > 2 then
      close(APty.FSlaveFd);
    close(APty.FMasterFd);

    if (ACwd <> nil) and (ACwd[0] <> #0) then
    begin
      if chdir(ACwd) <> 0 then
      begin
        LErrno := platform_get_errno;
        WriteSpawnError(LErrPipe[1], ptssChdir, LErrno);
        posix_exit(127);
      end;
    end;

    if AEnvp <> nil then
      execve(APath, AArgv, AEnvp)
    else
      execvp(APath, AArgv);

    LErrno := platform_get_errno;
    WriteSpawnError(LErrPipe[1], ptssExec, LErrno);
    posix_exit(127);
  end;

  { parent }
  close(LErrPipe[1]);
  close(APty.FSlaveFd);
  APty.FSlaveFd := -1;

  FillChar(LWire, SizeOf(LWire), 0);
  LN := read(LErrPipe[0], @LWire, SizeOf(LWire));
  close(LErrPipe[0]);

  if LN = SizeOf(LWire) then
  begin
    waitpid(LPid, nil, 0);
    AFailStage := TPlatformPtySpawnStage(LWire.Stage);
    Exit(LWire.ErrNo);
  end;

  APid := Int32(LPid);
  Result := 0;
end;

function platform_pty_resize(var APty: TPlatformPty;
  const ASize: TPlatformPtySize): Int32;
var
  LWs: winsize;
begin
  LWs.ws_col := ASize.FCols;
  LWs.ws_row := ASize.FRows;
  LWs.ws_xpixel := ASize.FXPixel;
  LWs.ws_ypixel := ASize.FYPixel;
  if ioctl(APty.FMasterFd, TIOCSWINSZ, @LWs) < 0 then
    Exit(platform_get_errno);
  Result := 0;
end;

function platform_pty_close(var APty: TPlatformPty): Int32;
begin
  Result := 0;
  if APty.FSlaveFd >= 0 then
  begin
    close(APty.FSlaveFd);
    APty.FSlaveFd := -1;
  end;
  if APty.FMasterFd >= 0 then
  begin
    if close(APty.FMasterFd) <> 0 then
      Result := platform_get_errno;
    APty.FMasterFd := -1;
  end;
end;

function platform_pty_master_fd(const APty: TPlatformPty): PtrInt;
begin
  Result := PtrInt(APty.FMasterFd);
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;

function platform_pty_open(const ASize: TPlatformPtySize;
  out APty: TPlatformPty): Int32;
var
  LSize: COORD;
  LPipeInRead, LPipeInWrite: HANDLE;
  LPipeOutRead, LPipeOutWrite: HANDLE;
  LHr: Int32;
begin
  FillChar(APty, SizeOf(APty), 0);
  LSize.X := Int16(ASize.FCols);
  LSize.Y := Int16(ASize.FRows);

  if not CreatePipe(@LPipeInRead, @LPipeInWrite, nil, 0) then
    Exit(Int32(GetLastError));
  if not CreatePipe(@LPipeOutRead, @LPipeOutWrite, nil, 0) then
  begin
    CloseHandle(LPipeInRead);
    CloseHandle(LPipeInWrite);
    Exit(Int32(GetLastError));
  end;

  LHr := CreatePseudoConsole(LSize, LPipeInRead, LPipeOutWrite, 0, APty.FConPty);
  CloseHandle(LPipeInRead);
  CloseHandle(LPipeOutWrite);

  if LHr <> 0 then
  begin
    CloseHandle(LPipeInWrite);
    CloseHandle(LPipeOutRead);
    Exit(LHr);
  end;

  APty.FPipeIn := PtrUInt(LPipeInWrite);
  APty.FPipeOut := PtrUInt(LPipeOutRead);
  Result := 0;
end;

function platform_pty_spawn(var APty: TPlatformPty;
  const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar;
  const ACwd: PAnsiChar; out APid: Int32;
  out AFailStage: TPlatformPtySpawnStage): Int32;
var
  LSiEx: STARTUPINFOEXA;
  LPi: PROCESS_INFORMATION;
  LAttrSize: PtrUInt;
  LAttrList: Pointer;
begin
  APid := -1;
  AFailStage := ptssNone;
  FillChar(LSiEx, SizeOf(LSiEx), 0);
  LSiEx.StartupInfo.cb := SizeOf(LSiEx);
  FillChar(LPi, SizeOf(LPi), 0);

  LAttrSize := 0;
  InitializeProcThreadAttributeList(nil, 1, 0, LAttrSize);
  LAttrList := GetMem(LAttrSize);
  if LAttrList = nil then Exit(Int32(8));

  if not InitializeProcThreadAttributeList(LAttrList, 1, 0, LAttrSize) then
  begin
    FreeMem(LAttrList);
    AFailStage := ptssPipe;
    Exit(Int32(GetLastError));
  end;

  if not UpdateProcThreadAttribute(LAttrList, 0,
    PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, APty.FConPty,
    SizeOf(HPCON), nil, nil) then
  begin
    DeleteProcThreadAttributeList(LAttrList);
    FreeMem(LAttrList);
    AFailStage := ptssTiocsctty;
    Exit(Int32(GetLastError));
  end;

  LSiEx.lpAttributeList := LAttrList;

  if not CreateProcessA(APath, nil, nil, nil, False,
    EXTENDED_STARTUPINFO_PRESENT, nil, ACwd,
    @LSiEx.StartupInfo, @LPi) then
  begin
    DeleteProcThreadAttributeList(LAttrList);
    FreeMem(LAttrList);
    AFailStage := ptssExec;
    Exit(Int32(GetLastError));
  end;

  DeleteProcThreadAttributeList(LAttrList);
  FreeMem(LAttrList);
  CloseHandle(LPi.hThread);
  APid := Int32(LPi.dwProcessId);
  CloseHandle(LPi.hProcess);
  Result := 0;
end;

function platform_pty_resize(var APty: TPlatformPty;
  const ASize: TPlatformPtySize): Int32;
var
  LSize: COORD;
begin
  LSize.X := Int16(ASize.FCols);
  LSize.Y := Int16(ASize.FRows);
  Result := ResizePseudoConsole(APty.FConPty, LSize);
end;

function platform_pty_close(var APty: TPlatformPty): Int32;
begin
  if APty.FConPty <> nil then
  begin
    ClosePseudoConsole(APty.FConPty);
    APty.FConPty := nil;
  end;
  if APty.FPipeIn <> 0 then
  begin
    CloseHandle(HANDLE(APty.FPipeIn));
    APty.FPipeIn := 0;
  end;
  if APty.FPipeOut <> 0 then
  begin
    CloseHandle(HANDLE(APty.FPipeOut));
    APty.FPipeOut := 0;
  end;
  Result := 0;
end;

function platform_pty_master_fd(const APty: TPlatformPty): PtrInt;
begin
  Result := PtrInt(APty.FPipeOut);
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_pty_open(const ASize: TPlatformPtySize; out APty: TPlatformPty): Int32;
begin FillChar(APty, SizeOf(APty), 0); Result := -1; end;
function platform_pty_spawn(var APty: TPlatformPty; const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; const ACwd: PAnsiChar; out APid: Int32; out AFailStage: TPlatformPtySpawnStage): Int32;
begin APid := -1; AFailStage := ptssNone; Result := -1; end;
function platform_pty_resize(var APty: TPlatformPty; const ASize: TPlatformPtySize): Int32;
begin Result := -1; end;
function platform_pty_close(var APty: TPlatformPty): Int32;
begin Result := -1; end;
function platform_pty_master_fd(const APty: TPlatformPty): PtrInt;
begin Result := -1; end;
{$ENDIF}

end.
