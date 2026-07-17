unit nextpas.core.platform.pty;
{**
 * @desc 跨平台伪终端：打开 PTY 对、spawn 子进程、resize、关闭。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.pty.base,
  nextpas.core.platform.posix.errno;

{** @desc 打开伪终端对
    @param ASize 终端尺寸
    @param APty 输出伪终端句柄
    @return 0 成功，否则返回错误码 *}
function platform_pty_open(const ASize: TPlatformPtySize;
  out APty: TPlatformPty): Int32;

{** @desc 在伪终端中启动子进程
    @param APty 伪终端句柄
    @param APath 可执行文件路径
    @param AArgv 参数数组（以 nil 结尾）
    @param AEnvp 环境变量数组（nil 表示继承）
    @param ACwd 工作目录（nil 表示继承）
    @param APid 输出子进程 PID
    @param AFailStage 输出失败阶段
    @return 0 成功，否则返回错误码 *}
function platform_pty_spawn(var APty: TPlatformPty;
  const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar;
  const ACwd: PAnsiChar; out APid: Int32;
  out AFailStage: TPlatformPtySpawnStage): Int32;

{** @desc 调整伪终端尺寸
    @param APty 伪终端句柄
    @param ASize 新尺寸
    @return 0 成功，否则返回错误码 *}
function platform_pty_resize(var APty: TPlatformPty;
  const ASize: TPlatformPtySize): Int32;

{** @desc 关闭伪终端
    @param APty 伪终端句柄（置为空）
    @return 0 成功，否则返回错误码 *}
function platform_pty_close(var APty: TPlatformPty): Int32;

{** @desc 获取伪终端主文件描述符
    @param APty 伪终端句柄
    @return 主文件描述符，-1 无效 *}
function platform_pty_master_fd(const APty: TPlatformPty): PtrInt;

implementation

{ L0: uses System GetMem/FreeMem (must not uses nextpas.core.mem; mem depends on platform). }

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
  APty.MasterFd := -1;
  APty.SlaveFd := -1;

  LWs.ws_col := ASize.Cols;
  LWs.ws_row := ASize.Rows;
  LWs.ws_xpixel := ASize.XPixel;
  LWs.ws_ypixel := ASize.YPixel;

  if openpty(@LMaster, @LSlave, nil, nil, @LWs) <> 0 then
    Exit(platform_get_errno);

  APty.MasterFd := LMaster;
  APty.SlaveFd := LSlave;
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

  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);

{$IFDEF NEXTPAS_LINUX}
  if pipe2(@LErrPipe[0], O_CLOEXEC) <> 0 then
{$ELSE}
  if pipe(@LErrPipe[0]) <> 0 then
{$ENDIF}
  begin
    AFailStage := ptssPipe;
    Exit(platform_get_errno);
  end;
{$IFNDEF NEXTPAS_LINUX}
  fcntl(LErrPipe[0], F_SETFD, FD_CLOEXEC);
  fcntl(LErrPipe[1], F_SETFD, FD_CLOEXEC);
{$ENDIF}

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
    { posix_exit is _exit; the forked child must not run Pascal finalizers. }
    close(LErrPipe[0]);

    if setsid < 0 then
    begin
      LErrno := platform_get_errno;
      WriteSpawnError(LErrPipe[1], ptssSetsid, LErrno);
      posix_exit(127);
    end;

    if ioctl(APty.SlaveFd, TIOCSCTTY, Pointer(0)) < 0 then
    begin
      LErrno := platform_get_errno;
      WriteSpawnError(LErrPipe[1], ptssTiocsctty, LErrno);
      posix_exit(127);
    end;

    if dup2(APty.SlaveFd, 0) < 0 then
    begin
      LErrno := platform_get_errno;
      WriteSpawnError(LErrPipe[1], ptssDup, LErrno);
      posix_exit(127);
    end;
    if dup2(APty.SlaveFd, 1) < 0 then
    begin
      LErrno := platform_get_errno;
      WriteSpawnError(LErrPipe[1], ptssDup, LErrno);
      posix_exit(127);
    end;
    if dup2(APty.SlaveFd, 2) < 0 then
    begin
      LErrno := platform_get_errno;
      WriteSpawnError(LErrPipe[1], ptssDup, LErrno);
      posix_exit(127);
    end;
    if APty.SlaveFd > 2 then
      close(APty.SlaveFd);
    close(APty.MasterFd);

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
  close(APty.SlaveFd);
  APty.SlaveFd := -1;

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
  LWs.ws_col := ASize.Cols;
  LWs.ws_row := ASize.Rows;
  LWs.ws_xpixel := ASize.XPixel;
  LWs.ws_ypixel := ASize.YPixel;
  if ioctl(APty.MasterFd, TIOCSWINSZ, @LWs) < 0 then
    Exit(platform_get_errno);
  Result := 0;
end;

function platform_pty_close(var APty: TPlatformPty): Int32;
begin
  Result := 0;
  if APty.SlaveFd >= 0 then
  begin
    close(APty.SlaveFd);
    APty.SlaveFd := -1;
  end;
  if APty.MasterFd >= 0 then
  begin
    if close(APty.MasterFd) <> 0 then
      Result := platform_get_errno;
    APty.MasterFd := -1;
  end;
end;

function platform_pty_master_fd(const APty: TPlatformPty): PtrInt; inline;
begin
  Result := PtrInt(APty.MasterFd);
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi,
  nextpas.core.platform.windows.utf16;

function platform_pty_open(const ASize: TPlatformPtySize;
  out APty: TPlatformPty): Int32;
var
  LSize: COORD;
  LPipeInRead, LPipeInWrite: HANDLE;
  LPipeOutRead, LPipeOutWrite: HANDLE;
  LHr: Int32;
begin
  FillChar(APty, SizeOf(APty), 0);
  LSize.X := Int16(ASize.Cols);
  LSize.Y := Int16(ASize.Rows);

  if not CreatePipe(@LPipeInRead, @LPipeInWrite, nil, 0) then
    Exit(platform_get_last_error);
  if not CreatePipe(@LPipeOutRead, @LPipeOutWrite, nil, 0) then
  begin
    CloseHandle(LPipeInRead);
    CloseHandle(LPipeInWrite);
    Exit(platform_get_last_error);
  end;

  LHr := CreatePseudoConsole(LSize, LPipeInRead, LPipeOutWrite, 0, APty.ConPty);
  CloseHandle(LPipeInRead);
  CloseHandle(LPipeOutWrite);

  if LHr <> 0 then
  begin
    CloseHandle(LPipeInWrite);
    CloseHandle(LPipeOutRead);
    Exit(LHr);
  end;

  APty.PipeIn := PtrUInt(LPipeInWrite);
  APty.PipeOut := PtrUInt(LPipeOutRead);
  Result := 0;
end;

function platform_pty_spawn(var APty: TPlatformPty;
  const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar;
  const ACwd: PAnsiChar; out APid: Int32;
  out AFailStage: TPlatformPtySpawnStage): Int32;
var
  LSiEx: STARTUPINFOEXW;
  LPi: PROCESS_INFORMATION;
  LAttrSize: PtrUInt;
  LAttrList: Pointer;
  LCmd: UnicodeString;
  LCwd: UnicodeString;
  LEnvBlock: UnicodeString;
  LCwdPtr: PWideChar;
  LEnvPtr: Pointer;
  LCreationFlags: DWORD;
begin
  APid := -1;
  AFailStage := ptssNone;
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  FillChar(LSiEx, SizeOf(LSiEx), 0);
  LSiEx.StartupInfo.cb := SizeOf(LSiEx);
  FillChar(LPi, SizeOf(LPi), 0);

  LAttrSize := 0;
  InitializeProcThreadAttributeList(nil, 1, 0, LAttrSize);
  LAttrList := GetMem(LAttrSize);
  if LAttrList = nil then Exit(PLATFORM_ERR_NOMEM);

  if not InitializeProcThreadAttributeList(LAttrList, 1, 0, LAttrSize) then
  begin
    FreeMem(LAttrList, LAttrSize);
    AFailStage := ptssPipe;
    Exit(platform_get_last_error);
  end;

  if not UpdateProcThreadAttribute(LAttrList, 0,
    PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, APty.ConPty,
    SizeOf(HPCON), nil, nil) then
  begin
    DeleteProcThreadAttributeList(LAttrList);
    FreeMem(LAttrList, LAttrSize);
    AFailStage := ptssTiocsctty;
    Exit(platform_get_last_error);
  end;

  LSiEx.lpAttributeList := LAttrList;

  if not platform_windows_argv_to_command_line(APath, AArgv, LCmd) then
  begin
    DeleteProcThreadAttributeList(LAttrList);
    FreeMem(LAttrList, LAttrSize);
    AFailStage := ptssExec;
    Exit(PLATFORM_ERR_INVALID);
  end;

  LCwdPtr := nil;
  if ACwd <> nil then
  begin
    if not platform_windows_utf8_to_wide_checked(ACwd, LCwd) then
    begin
      DeleteProcThreadAttributeList(LAttrList);
      FreeMem(LAttrList, LAttrSize);
      AFailStage := ptssChdir;
      Exit(PLATFORM_ERR_INVALID);
    end;
    LCwdPtr := PWideChar(LCwd);
  end;

  LEnvPtr := nil;
  LCreationFlags := EXTENDED_STARTUPINFO_PRESENT;
  if AEnvp <> nil then
  begin
    if not platform_windows_envp_to_wide_block(AEnvp, LEnvBlock) then
    begin
      DeleteProcThreadAttributeList(LAttrList);
      FreeMem(LAttrList, LAttrSize);
      AFailStage := ptssExec;
      Exit(PLATFORM_ERR_INVALID);
    end;
    LEnvPtr := PWideChar(LEnvBlock);
    LCreationFlags := LCreationFlags or CREATE_UNICODE_ENVIRONMENT;
  end;

  if not CreateProcessW(nil, PWideChar(LCmd), nil, nil, False,
    LCreationFlags, LEnvPtr, LCwdPtr, @LSiEx.StartupInfo, @LPi) then
  begin
    DeleteProcThreadAttributeList(LAttrList);
    FreeMem(LAttrList, LAttrSize);
    AFailStage := ptssExec;
    Exit(platform_get_last_error);
  end;

  DeleteProcThreadAttributeList(LAttrList);
  FreeMem(LAttrList, LAttrSize);
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
  LSize.X := Int16(ASize.Cols);
  LSize.Y := Int16(ASize.Rows);
  Result := ResizePseudoConsole(APty.ConPty, LSize);
end;

function platform_pty_close(var APty: TPlatformPty): Int32;
begin
  if APty.ConPty <> nil then
  begin
    ClosePseudoConsole(APty.ConPty);
    APty.ConPty := nil;
  end;
  if APty.PipeIn <> 0 then
  begin
    CloseHandle(HANDLE(APty.PipeIn));
    APty.PipeIn := 0;
  end;
  if APty.PipeOut <> 0 then
  begin
    CloseHandle(HANDLE(APty.PipeOut));
    APty.PipeOut := 0;
  end;
  Result := 0;
end;

function platform_pty_master_fd(const APty: TPlatformPty): PtrInt;
begin
  if APty.PipeOut = 0 then
    Exit(-1);
  Result := PtrInt(APty.PipeOut);
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_pty_open(const ASize: TPlatformPtySize; out APty: TPlatformPty): Int32;
begin FillChar(APty, SizeOf(APty), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_pty_spawn(var APty: TPlatformPty; const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; const ACwd: PAnsiChar; out APid: Int32; out AFailStage: TPlatformPtySpawnStage): Int32;
begin APid := -1; AFailStage := ptssNone; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_pty_resize(var APty: TPlatformPty; const ASize: TPlatformPtySize): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_pty_close(var APty: TPlatformPty): Int32;
begin FillChar(APty, SizeOf(APty), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_pty_master_fd(const APty: TPlatformPty): PtrInt;
begin Result := -1; end;
{$ENDIF}

end.
