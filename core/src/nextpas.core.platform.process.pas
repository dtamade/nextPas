unit nextpas.core.platform.process;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.process.base,
  nextpas.core.platform.posix.errno;

{** @desc 创建子进程
    @param APath 可执行文件路径
    @param AArgv 参数数组（以 nil 结尾）
    @param AEnvp 环境变量数组（nil 表示继承当前环境）
    @param AProc 输出进程句柄
    @return 0 成功，否则返回错误码 *}
function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;

{** @desc 创建子进程并重定向标准 I/O
    @param APath 可执行文件路径
    @param AArgv 参数数组（以 nil 结尾）
    @param AEnvp 环境变量数组（nil 表示继承当前环境）
    @param ACwd 工作目录（nil 表示继承当前目录）
    @param AChildStdin 子进程 stdin 文件描述符（-1 表示不重定向）
    @param AChildStdout 子进程 stdout 文件描述符（-1 表示不重定向）
    @param AChildStderr 子进程 stderr 文件描述符（-1 表示不重定向）
    @param AProc 输出进程句柄
    @param AFailStage 输出失败阶段
    @return 0 成功，否则返回错误码 *}
function platform_process_spawn_fds(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  AChildStdin, AChildStdout, AChildStderr: PtrInt;
  out AProc: TPlatformProcess;
  out AFailStage: TPlatformProcessSpawnStage): Int32;

{** @desc spawn_fds 扩展：额外 fd + 可选 setuid/setgid + 可选新进程组
    @param AExtraFds 父进程 fd 列表（可为 nil）
    @param AExtraFdCount 额外 fd 数量
    @param ASetCred True 时在 exec 前 setgid+setuid
    @param AUid/AGid 凭证（仅 ASetCred 时有效）
    @param ANewProcessGroup True 时子进程 setpgid(0,0)（Unix；Win UNSUPPORTED）
    @note Unix；Windows 在 ExtraFd/Cred/NewProcessGroup 时返回 UNSUPPORTED *}
function platform_process_spawn_fds_ex(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  AChildStdin, AChildStdout, AChildStderr: PtrInt;
  AExtraFds: PPtrInt; AExtraFdCount: Int32;
  ASetCred: Boolean; AUid, AGid: UInt32;
  ANewProcessGroup: Boolean;
  out AProc: TPlatformProcess;
  out AFailStage: TPlatformProcessSpawnStage): Int32;

{** @desc 运行进程并捕获 stdout 输出
    @param APath 可执行文件路径
    @param AArgv 参数数组（以 nil 结尾）
    @param ACwd 工作目录（nil 表示继承当前目录）
    @param AOutBuf 输出缓冲区
    @param AOutBufLen 缓冲区长度
    @param AOutLen 输出实际读取字节数
    @param AExitCode 输出进程退出码
    @return 0 成功，否则返回错误码 *}
function platform_process_run(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar; AOutBuf: PAnsiChar; AOutBufLen: Int32;
  out AOutLen: Int32; out AExitCode: Int32): Int32;

{** @desc 运行进程并同时捕获 stdout/stderr
    @note Windows implementation currently captures stdout only; stderr 长度返回 0。
    @param APath 可执行文件路径
    @param AArgv 参数数组（以 nil 结尾）
    @param ACwd 工作目录（nil 表示继承当前目录）
    @param AStdoutBuf stdout 缓冲区
    @param AStdoutBufLen stdout 缓冲区长度
    @param AStdoutLen stdout 实际读取字节数
    @param AStderrBuf stderr 缓冲区
    @param AStderrBufLen stderr 缓冲区长度
    @param AStderrLen stderr 实际读取字节数
    @param AExitCode 输出进程退出码
    @return 0 成功，否则返回错误码 *}
function platform_process_run_capture(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar;
  AStdoutBuf: PAnsiChar; AStdoutBufLen: Int32; out AStdoutLen: Int32;
  AStderrBuf: PAnsiChar; AStderrBufLen: Int32; out AStderrLen: Int32;
  out AExitCode: Int32): Int32;

{** @desc 等待进程结束（可选超时）
    @param AProc 进程句柄
    @param AResult 输出进程结果
    @param ATimeoutMs 超时时间（毫秒，0 表示无限等待）
    @return 0 成功，PLATFORM_ERR_TIMEDOUT 超时 *}
function platform_process_wait(const AProc: TPlatformProcess;
  out AResult: TPlatformProcessResult; ATimeoutMs: Int64 = 0): Int32;

{** @desc 非阻塞检查进程是否结束
    @param AProc 进程句柄
    @param AResult 输出进程结果
    @return 0 成功（进程已结束或仍在运行） *}
function platform_process_try_wait(const AProc: TPlatformProcess;
  out AResult: TPlatformProcessResult): Int32;

{** @desc 分离进程（不再等待其结束）
    @param AProc 进程句柄（置为空） *}
procedure platform_process_detach(var AProc: TPlatformProcess);

{** @desc 向进程发送信号
    @param AProc 进程句柄
    @param ASignal 信号编号
    @return 0 成功，否则返回错误码 *}
function platform_process_signal(const AProc: TPlatformProcess; ASignal: Int32): Int32;

{** @desc 强制终止进程（SIGKILL）
    @param AProc 进程句柄
    @return 0 成功，否则返回错误码 *}
function platform_process_kill(const AProc: TPlatformProcess): Int32;

{** @desc 向进程组发信号（Unix kill(-pgid,sig)；pgid>0）
    @return 0 成功；Windows 返回 UNSUPPORTED *}
function platform_process_kill_group(APgid: Int32; ASignal: Int32): Int32;

{** @desc 获取进程 ID
    @param AProc 进程句柄
    @return 进程 ID *}
function platform_process_pid(const AProc: TPlatformProcess): Int32;

{** @desc 获取当前进程 ID
    @return 当前进程 ID *}
function platform_getpid: Int32;

{** @desc 创建管道（用于进程间通信）
    @param AReadHandle 输出读端文件描述符
    @param AWriteHandle 输出写端文件描述符
    @return 0 成功，否则返回错误码 *}
function platform_process_create_pipe(out AReadHandle, AWriteHandle: PtrInt): Int32;

{** @desc 打开 /dev/null
    @param AForWrite True 打开用于写入，False 打开用于读取
    @param AHandle 输出文件描述符
    @return 0 成功，否则返回错误码 *}
function platform_process_open_null(const AForWrite: Boolean; out AHandle: PtrInt): Int32;

{** @desc 关闭文件描述符
    @param AHandle 文件描述符（置为 -1）
    @return 0 成功，否则返回错误码 *}
function platform_process_close_handle(var AHandle: PtrInt): Int32;

{** @desc 设置句柄是否可被子进程继承
    @param AHandle  管道/文件句柄
    @param AInherit True=可继承；False=父进程保留端应设为不可继承
    @return 0 成功 *}
function platform_process_set_handle_inheritable(AHandle: PtrInt;
  AInherit: Boolean): Int32;

{ Generic fd I/O — transitional dual-API for process.pipe only.
  Prefer platform.files / platform_process_*_ex for new code.
  platform_io_read/write/poll: value/sentinel (byte count or ready count; -1 on failure).
  platform_io_close: error-code (0 / PLATFORM_ERR_*). }

{** @desc 从文件描述符读取数据（自动重试 EINTR）
    @note Transitional dual-API for process.pipe; prefer platform.files / *_ex.
    @param AFd 文件描述符
    @param ABuf 读取缓冲区
    @param ACount 读取字节数
    @return 读取的字节数，0 表示 EOF，负值表示错误 *}
function platform_io_read(AFd: PtrInt; ABuf: Pointer; ACount: SizeUInt): PtrInt;

{** @desc 向文件描述符写入数据（自动重试 EINTR，处理部分写入）
    @note Transitional dual-API for process.pipe; prefer platform.files / *_ex.
    @param AFd 文件描述符
    @param ABuf 写入缓冲区
    @param ACount 写入字节数
    @return 写入的字节数，负值表示错误 *}
function platform_io_write(AFd: PtrInt; ABuf: Pointer; ACount: SizeUInt): PtrInt;

{** @desc 关闭文件描述符
    @param AFd 文件描述符
    @return 0 成功，否则返回错误码 *}
function platform_io_close(AFd: PtrInt): Int32;

{** @desc I/O 多路复用等待（poll，自动重试 EINTR）
    @note Transitional dual-API for process.pipe; prefer platform.io poller for new code.
    @param AFds pollfd 数组
    @param ACount 文件描述符数量
    @param ATimeoutMs 超时时间（毫秒，-1 表示无限等待）
    @return 就绪的描述符数量，0 表示超时，负值表示错误 *}
function platform_io_poll(AFds: Pointer; ACount: Int32; ATimeoutMs: Int32): Int32;

{ Process convenience functions }

{** @desc 运行进程并捕获输出（便利函数）
    @param APath 可执行文件路径
    @param AArgv 参数数组（以 nil 结尾）
    @param ACwd 工作目录（nil 表示继承当前目录）
    @param AStdoutBuf stdout 缓冲区（nil 表示不捕获）
    @param AStdoutBufLen stdout 缓冲区长度
    @param AStderrBuf stderr 缓冲区（nil 表示不捕获）
    @param AStderrBufLen stderr 缓冲区长度
    @param AResult 输出执行结果
    @return 0 成功，否则返回错误码 *}
function platform_process_run_exec(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar;
  AStdoutBuf: PAnsiChar; AStdoutBufLen: Int32;
  AStderrBuf: PAnsiChar; AStderrBufLen: Int32;
  out AResult: TPlatformProcessExecResult): Int32;

{** @desc 创建带管道的进程（便利函数）
    @param APath 可执行文件路径
    @param AArgv 参数数组（以 nil 结尾）
    @param ACwd 工作目录（nil 表示继承当前目录）
    @param AOptions 进程选项
    @param AProc 输出进程句柄
    @param APipes 输出管道集合
    @return 0 成功，否则返回错误码 *}
function platform_process_create_piped(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar; AOptions: TPlatformProcessOptions;
  out AProc: TPlatformProcess; out APipes: TPlatformProcessPipes): Int32;

{** @desc 向进程 stdin 写入数据（规范错误码版本）
    @param AStdinWrite stdin 写端文件描述符
    @param AData 写入数据
    @param ALen 数据长度
    @param ABytesWritten 输出实际写入字节数
    @return 0 成功，否则返回错误码 *}
function platform_process_write_stdin_ex(AStdinWrite: PtrInt;
  AData: PAnsiChar; ALen: Int32; out ABytesWritten: Int32): Int32;

{** @desc 从进程 stdout 读取数据（规范错误码版本）
    @param AStdoutRead stdout 读端文件描述符
    @param ABuf 输出缓冲区
    @param ABufLen 缓冲区长度
    @param ABytesRead 输出实际读取字节数；EOF 或非阻塞无数据时为 0
    @return 0 成功，否则返回错误码 *}
function platform_process_read_stdout_ex(AStdoutRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;

{** @desc 从进程 stderr 读取数据（规范错误码版本）
    @param AStderrRead stderr 读端文件描述符
    @param ABuf 输出缓冲区
    @param ABufLen 缓冲区长度
    @param ABytesRead 输出实际读取字节数；EOF 或非阻塞无数据时为 0
    @return 0 成功，否则返回错误码 *}
function platform_process_read_stderr_ex(AStderrRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;

{** @desc 向进程 stdin 写入数据
    @note 兼容接口：成功返回写入字节数；普通失败返回 -1；
          unsupported 平台返回 PLATFORM_ERR_UNSUPPORTED。
    @param AStdinWrite stdin 写端文件描述符
    @param AData 写入数据
    @param ALen 数据长度
    @return 写入字节数，-1 失败 *}
function platform_process_write_stdin(AStdinWrite: PtrInt;
  AData: PAnsiChar; ALen: Int32): Int32;
  deprecated 'Use platform_process_write_stdin_ex';

{** @desc 从进程 stdout 读取数据
    @note 兼容接口：成功返回读取字节数；EOF 返回 0；普通失败返回 -1；
          unsupported 平台返回 PLATFORM_ERR_UNSUPPORTED。
    @param AStdoutRead stdout 读端文件描述符
    @param ABuf 输出缓冲区
    @param ABufLen 缓冲区长度
    @return 读取字节数，0 表示 EOF，-1 失败 *}
function platform_process_read_stdout(AStdoutRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
  deprecated 'Use platform_process_read_stdout_ex';

{** @desc 从进程 stderr 读取数据
    @note 兼容接口：成功返回读取字节数；EOF 返回 0；普通失败返回 -1；
          unsupported 平台返回 PLATFORM_ERR_UNSUPPORTED。
    @param AStderrRead stderr 读端文件描述符
    @param ABuf 输出缓冲区
    @param ABufLen 缓冲区长度
    @return 读取字节数，0 表示 EOF，-1 失败 *}
function platform_process_read_stderr(AStderrRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32): Int32;
  deprecated 'Use platform_process_read_stderr_ex';

implementation

{$IFDEF NEXTPAS_UNIX}
{$IF defined(NEXTPAS_LINUX) and (defined(NEXTPAS_X86_64) or defined(NEXTPAS_AARCH64))}
  {$DEFINE NEXTPAS_PROCESS_HAS_CLOSE_RANGE}
{$ENDIF}
uses
  nextpas.core.platform.error,
  nextpas.core.platform.signal,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.helpers,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.time
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.base
  , nextpas.core.platform.darwin.ffi
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  , nextpas.core.platform.freebsd.base
  , nextpas.core.platform.freebsd.ffi
{$ENDIF}
{$IFDEF NEXTPAS_PROCESS_HAS_CLOSE_RANGE}
  , nextpas.core.platform.linux.modern
{$ENDIF}
  ;

function IsInvalidOutputBuffer(ABuf: PAnsiChar; ABufLen: Int32): Boolean; inline;
begin
  Result := (ABufLen < 0) or ((ABuf = nil) and (ABufLen > 0));
end;

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
  begin
    Result := PLATFORM_CHILD_FD_FALLBACK_MAX;
    Exit;
  end;
  if LOpenMax > PLATFORM_CHILD_FD_FALLBACK_MAX then
  begin
    Result := PLATFORM_CHILD_FD_FALLBACK_MAX;
    Exit;
  end;
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

procedure CloseChildFdLoopKeep(APreserveFd: Int32; AKeepThrough: Int32);
var
  LFd: Int32;
  LLastFd: Int32;
begin
  LLastFd := ChildFdCloseMax;
  for LFd := PLATFORM_CHILD_FD_FIRST to LLastFd do
    if (LFd <> APreserveFd) and (LFd > AKeepThrough) then
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

function TryCloseChildFdsWithCloseRangeKeep(APreserveFd: Int32;
  AKeepThrough: Int32): Boolean;
var
  LStart: cuint;
begin
  { Keep 0..AKeepThrough and APreserveFd; close the rest. }
  if AKeepThrough < 2 then
    AKeepThrough := 2;
  LStart := cuint(AKeepThrough + 1);
  if APreserveFd >= Int32(LStart) then
  begin
    { close [start, preserve-1] and [preserve+1, high] }
    if APreserveFd > Int32(LStart) then
      Result := TryCloseRangeSegment(LStart, cuint(APreserveFd - 1))
    else
      Result := True;
    if not Result then
      Exit;
    Result := TryCloseRangeSegment(cuint(APreserveFd) + 1, High(cuint));
  end
  else
    Result := TryCloseRangeSegment(LStart, High(cuint));
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

procedure CloseChildFdsExceptKeep(APreserveFd: Int32; AKeepThrough: Int32);
begin
{$IFDEF NEXTPAS_PROCESS_HAS_CLOSE_RANGE}
  if TryCloseChildFdsWithCloseRangeKeep(APreserveFd, AKeepThrough) then
    Exit;
{$ENDIF}
  CloseChildFdLoopKeep(APreserveFd, AKeepThrough);
end;

function platform_process_create_pipe(out AReadHandle, AWriteHandle: PtrInt): Int32;
var
  LPipe: array[0..1] of Int32;
begin
  AReadHandle := -1;
  AWriteHandle := -1;
  Result := PosixCheck(pipe(@LPipe[0]));
  if Result = 0 then
  begin
    AReadHandle := LPipe[0];
    AWriteHandle := LPipe[1];
  end;
end;

function platform_process_open_null(const AForWrite: Boolean; out AHandle: PtrInt): Int32;
var
  LFd: cint;
  LHandle: Int32;
begin
  if AForWrite then
    LFd := open('/dev/null', 1, 0)
  else
    LFd := open('/dev/null', 0, 0);
  Result := PosixFdToHandle(LFd, LHandle);
  if Result = 0 then
    AHandle := LHandle
  else
    AHandle := -1;
end;

function platform_process_close_handle(var AHandle: PtrInt): Int32;
begin
  if AHandle < 0 then
    Exit(0);
  Result := PosixCheck(close(cint(AHandle)));
  if Result = 0 then
    AHandle := -1;
end;

function platform_process_set_handle_inheritable(AHandle: PtrInt;
  AInherit: Boolean): Int32;
var
  LFlags: cint;
begin
  if AHandle < 0 then
    Exit(PLATFORM_ERR_INVALID);
  LFlags := fcntl(cint(AHandle), F_GETFD, 0);
  if LFlags < 0 then
    Exit(platform_get_errno);
  if AInherit then
    LFlags := LFlags and (not FD_CLOEXEC)
  else
    LFlags := LFlags or FD_CLOEXEC;
  if fcntl(cint(AHandle), F_SETFD, LFlags) < 0 then
    Exit(platform_get_errno);
  Result := 0;
end;

function platform_io_read(AFd: PtrInt; ABuf: Pointer; ACount: SizeUInt): PtrInt;
var
  LRead: ssize_t;
begin
  if (AFd < 0) or (ABuf = nil) or (ACount = 0) then
    Exit(-1);
  repeat
    LRead := read(cint(AFd), ABuf, ACount);
    if LRead >= 0 then
      Exit(LRead);
    if platform_get_errno = ESysEINTR then
      Continue;
    Exit(-1);
  until False;
end;

function platform_io_write(AFd: PtrInt; ABuf: Pointer; ACount: SizeUInt): PtrInt;
var
  LWritten: ssize_t;
  LTotal: SizeUInt;
begin
  if (AFd < 0) or (ABuf = nil) or (ACount = 0) then
    Exit(-1);
  LTotal := 0;
  repeat
    LWritten := write(cint(AFd), Pointer(PtrUInt(ABuf) + LTotal), ACount - LTotal);
    if LWritten > 0 then
    begin
      Inc(LTotal, SizeUInt(LWritten));
      if LTotal = ACount then
        Exit(PtrInt(LTotal));
      Continue;
    end;
    if LWritten = 0 then
      Exit(-1);
    if platform_get_errno = ESysEINTR then
      Continue;
    Exit(-1);
  until False;
end;

function platform_io_close(AFd: PtrInt): Int32;
begin
  if AFd < 0 then
    Exit(0);
  Result := PosixCheck(close(cint(AFd)));
end;

function platform_io_poll(AFds: Pointer; ACount: Int32; ATimeoutMs: Int32): Int32;
var
  LPollResult: Int32;
begin
  if (AFds = nil) or (ACount <= 0) then
    Exit(-1);
  repeat
    LPollResult := poll(AFds, cuint(ACount), ATimeoutMs);
    if LPollResult >= 0 then
      Exit(LPollResult);
    if platform_get_errno = ESysEINTR then
      Continue;
    Exit(-1);
  until False;
end;

function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
var
  LPid: pid_t;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  LPid := fork;
  if LPid < 0 then
    Exit(platform_get_errno);
  if LPid = 0 then
  begin
    if AEnvp <> nil then
      execve(APath, AArgv, AEnvp)
    else
      execvp(APath, AArgv);
    posix_exit(127);
  end;
  AProc.Pid := LPid;
  Result := 0;
end;

function platform_process_spawn_fds(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  AChildStdin, AChildStdout, AChildStderr: PtrInt;
  out AProc: TPlatformProcess;
  out AFailStage: TPlatformProcessSpawnStage): Int32;
begin
  Result := platform_process_spawn_fds_ex(APath, AArgv, AEnvp, ACwd,
    AChildStdin, AChildStdout, AChildStderr, nil, 0, False, 0, 0, False,
    AProc, AFailStage);
end;

function platform_process_spawn_fds_ex(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  AChildStdin, AChildStdout, AChildStderr: PtrInt;
  AExtraFds: PPtrInt; AExtraFdCount: Int32;
  ASetCred: Boolean; AUid, AGid: UInt32;
  ANewProcessGroup: Boolean;
  out AProc: TPlatformProcess;
  out AFailStage: TPlatformProcessSpawnStage): Int32;
var
  LPid: pid_t;
  LErrPipe: array[0..1] of Int32;
  LWire: TPosixSpawnWireError;
  LRead: ssize_t;
  LI: Int32;
  LKeepThrough: Int32;
  LTargetFd: Int32;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  AFailStage := pssNone;

  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  if (AExtraFdCount < 0) or ((AExtraFdCount > 0) and (AExtraFds = nil)) then
    Exit(PLATFORM_ERR_INVALID);

{$IFDEF NEXTPAS_LINUX}
  if pipe2(@LErrPipe[0], O_CLOEXEC) <> 0 then
{$ELSE}
  if pipe(@LErrPipe[0]) <> 0 then
{$ENDIF}
  begin
    AFailStage := pssPipe;
    Exit(platform_get_errno);
  end;
{$IFNDEF NEXTPAS_LINUX}
  fcntl(LErrPipe[0], F_SETFD, FD_CLOEXEC);
  fcntl(LErrPipe[1], F_SETFD, FD_CLOEXEC);
{$ENDIF}

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

    if ANewProcessGroup then
      if setpgid(0, 0) <> 0 then
      begin
        LWire.Stage := Ord(pssExec);
        LWire.ErrNo := platform_get_errno;
        write(LErrPipe[1], @LWire, SizeOf(LWire));
        posix_exit(127);
      end;

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

    { ExtraFiles: parent FDs → child 3,4,5,... (Go ExtraFiles) }
    for LI := 0 to AExtraFdCount - 1 do
    begin
      LTargetFd := 3 + LI;
      if PtrInt(AExtraFds[LI]) < 0 then
        Continue;
      if dup2(Int32(AExtraFds[LI]), LTargetFd) < 0 then
      begin
        LWire.Stage := Ord(pssDupStderr); { reuse stage bucket for extra }
        LWire.ErrNo := platform_get_errno;
        write(LErrPipe[1], @LWire, SizeOf(LWire));
        posix_exit(127);
      end;
    end;

    LKeepThrough := 2 + AExtraFdCount; { keep 0..LKeepThrough }
    CloseChildFdsExceptKeep(LErrPipe[1], LKeepThrough);

    if ASetCred then
    begin
      if setgid(gid_t(AGid)) <> 0 then
      begin
        LWire.Stage := Ord(pssExec);
        LWire.ErrNo := platform_get_errno;
        write(LErrPipe[1], @LWire, SizeOf(LWire));
        posix_exit(127);
      end;
      if setuid(uid_t(AUid)) <> 0 then
      begin
        LWire.Stage := Ord(pssExec);
        LWire.ErrNo := platform_get_errno;
        write(LErrPipe[1], @LWire, SizeOf(LWire));
        posix_exit(127);
      end;
    end;

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
  repeat
    LRead := read(LErrPipe[0], @LWire, SizeOf(LWire));
  until (LRead >= 0) or (platform_get_errno <> ESysEINTR);
  close(LErrPipe[0]);

  if LRead = 0 then
  begin
    { Best-effort: ensure child is group leader (race-safe with child setpgid). }
    if ANewProcessGroup then
      setpgid(LPid, LPid);
    AProc.Pid := LPid;
    Result := 0;
  end
  else
  begin
    repeat
      LRead := waitpid(LPid, nil, 0);
    until (LRead >= 0) or (platform_get_errno <> ESysEINTR);
    AFailStage := TPlatformProcessSpawnStage(LWire.Stage);
    Result := LWire.ErrNo;
  end;
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
    { Unix convention: exit code = 128 + signum (e.g. 137 for SIGKILL) }
    AResult.ExitCode := 128 + (AWaitStatus and $7F);
  end
  else
    AResult.Status := psUnknown;
  Result := 0;
end;

function platform_process_wait(const AProc: TPlatformProcess;
  out AResult: TPlatformProcessResult; ATimeoutMs: Int64): Int32;
var
  LStatus: Int32;
  LRet: pid_t;
  LDeadlineNs, LNowNs: TPlatformTimeNanoseconds;
  LSleepReq: timespec;
  LWaitIter: Int32;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LStatus := 0;
  if ATimeoutMs <= 0 then
  begin
    repeat
      LRet := waitpid(AProc.Pid, @LStatus, 0);
    until (LRet >= 0) or (platform_get_errno <> ESysEINTR);
  end
  else
  begin
    LWaitIter := 0;
    LDeadlineNs := platform_monotonic_ns + TPlatformTimeNanoseconds(ATimeoutMs) * 1000000;
    repeat
      LRet := waitpid(AProc.Pid, @LStatus, WNOHANG);
      if LRet > 0 then
        Break;
      if LRet < 0 then
      begin
        if platform_get_errno = ESysEINTR then
        begin
          LRet := 0;
          Continue;
        end;
        Break;
      end;
      { LRet = 0: process still running }
      LNowNs := platform_monotonic_ns;
      if LNowNs >= LDeadlineNs then
      begin
        AResult.Status := psRunning;
        Exit(PLATFORM_ERR_TIMEDOUT);
      end;
      { Exponential backoff: 0ns → 10μs → 100μs → 1ms → 10ms cap }
      case LWaitIter of
        0: LSleepReq.tv_nsec := 0;
        1: LSleepReq.tv_nsec := 10000;      { 10 μs }
        2: LSleepReq.tv_nsec := 100000;     { 100 μs }
        3: LSleepReq.tv_nsec := 1000000;    { 1 ms }
      else
        begin
          LSleepReq.tv_sec := 0;
          LSleepReq.tv_nsec := 10000000;    { 10 ms cap }
        end;
      end;
      LSleepReq.tv_sec := 0;
      Inc(LWaitIter);
      nanosleep(@LSleepReq, nil);
    until False;
  end;
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

function platform_process_signal(const AProc: TPlatformProcess; ASignal: Int32): Int32;
begin
  if kill(AProc.Pid, ASignal) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_process_kill(const AProc: TPlatformProcess): Int32;
begin
  Result := platform_process_signal(AProc, PLATFORM_SIGKILL);
end;

function platform_process_kill_group(APgid: Int32; ASignal: Int32): Int32;
begin
  if APgid <= 0 then
    Exit(PLATFORM_ERR_INVALID);
  if kill(pid_t(-APgid), ASignal) = 0 then
    Result := 0
  else
    Result := platform_get_errno;
end;

function platform_process_pid(const AProc: TPlatformProcess): Int32;
begin
  Result := AProc.Pid;
end;

function platform_getpid: Int32;
begin
  Result := Int32(getpid);
end;

function platform_process_run(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar; AOutBuf: PAnsiChar; AOutBufLen: Int32;
  out AOutLen: Int32; out AExitCode: Int32): Int32;
var
  LProc: TPlatformProcess;
  LResult: TPlatformProcessResult;
  LStdoutPipe: array[0..1] of Int32;
  LDevNullRead, LDevNullWrite: Int32;
  LFailStage: TPlatformProcessSpawnStage;
  LN: PtrInt;
  LTotal: Int32;
  LDiscard: array[0..4095] of Byte;
begin
  AOutLen := 0;
  AExitCode := -1;
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  if IsInvalidOutputBuffer(AOutBuf, AOutBufLen) then
    Exit(PLATFORM_ERR_INVALID);
  LStdoutPipe[0] := -1;
  LStdoutPipe[1] := -1;
  LDevNullRead := -1;
  LDevNullWrite := -1;

  if pipe(@LStdoutPipe[0]) <> 0 then
    Exit(platform_get_errno);
  LDevNullRead := open('/dev/null', 0, 0);
  if LDevNullRead < 0 then
  begin
    Result := platform_get_errno;
    close(LStdoutPipe[0]);
    close(LStdoutPipe[1]);
    Exit;
  end;
  LDevNullWrite := open('/dev/null', 1, 0);
  if LDevNullWrite < 0 then
  begin
    Result := platform_get_errno;
    close(LDevNullRead);
    close(LStdoutPipe[0]);
    close(LStdoutPipe[1]);
    Exit;
  end;

  Result := platform_process_spawn_fds(APath, AArgv, nil, ACwd, LDevNullRead,
    LStdoutPipe[1], LDevNullWrite, LProc, LFailStage);
  close(LDevNullRead);
  close(LDevNullWrite);
  close(LStdoutPipe[1]);
  if Result <> 0 then
  begin
    close(LStdoutPipe[0]);
    Exit;
  end;

  try
    LTotal := 0;
    repeat
      if LTotal < AOutBufLen then
        LN := read(LStdoutPipe[0], @AOutBuf[LTotal], AOutBufLen - LTotal)
      else
        LN := read(LStdoutPipe[0], @LDiscard[0], SizeOf(LDiscard));
      if LN < 0 then
      begin
        if platform_get_errno = ESysEINTR then
          Continue;
        Break;
      end;
      if (LN > 0) and (LTotal < AOutBufLen) then
        Inc(LTotal, Int32(LN));
    until LN = 0;
    if LTotal < AOutBufLen then
      AOutBuf[LTotal] := #0;
    AOutLen := LTotal;
  finally
    close(LStdoutPipe[0]);
  end;

  Result := platform_process_wait(LProc, LResult);
  if Result = 0 then
    AExitCode := LResult.ExitCode;
end;

function ReadPipeFully(AFd: Int32; ABuf: PAnsiChar; ABufLen: Int32; out ALen: Int32): Int32;
var
  LN: PtrInt;
begin
  ALen := 0;
  if ABufLen <= 0 then
    Exit(0);
  repeat
    LN := read(AFd, @ABuf[ALen], ABufLen - ALen);
    if LN < 0 then
    begin
      if platform_get_errno = ESysEINTR then
        Continue;
      Exit(platform_get_errno);
    end;
    if LN > 0 then
      Inc(ALen, Int32(LN));
  until (LN = 0) or (ALen >= ABufLen);
  if ALen < ABufLen then
    ABuf[ALen] := #0;
  Result := 0;
end;

function ReadTwoPipes(AStdoutFd, AStderrFd: Int32;
  AStdoutBuf: PAnsiChar; AStdoutBufLen: Int32; out AStdoutLen: Int32;
  AStderrBuf: PAnsiChar; AStderrBufLen: Int32; out AStderrLen: Int32): Int32;
var
  LPollFds: array[0..1] of TPollFd;
  LRet, LN: PtrInt;
  LAnyOpen: Boolean;
  LStdoutEOF, LStderrEOF: Boolean;
  LDiscard: array[0..4095] of Byte;
begin
  AStdoutLen := 0;
  AStderrLen := 0;
  if IsInvalidOutputBuffer(AStdoutBuf, AStdoutBufLen) or
     IsInvalidOutputBuffer(AStderrBuf, AStderrBufLen) then
    Exit(PLATFORM_ERR_INVALID);
  LStdoutEOF := False;
  LStderrEOF := False;

  { Set non-blocking on both fds }
  fcntl(AStdoutFd, F_SETFL, fcntl(AStdoutFd, F_GETFL, 0) or O_NONBLOCK);
  fcntl(AStderrFd, F_SETFL, fcntl(AStderrFd, F_GETFL, 0) or O_NONBLOCK);

  repeat
    FillChar(LPollFds[0], SizeOf(LPollFds), 0);
    LAnyOpen := False;

    if not LStdoutEOF then
    begin
      LPollFds[0].fd := AStdoutFd;
      LPollFds[0].events := POLLIN;
      LAnyOpen := True;
    end
    else
      LPollFds[0].fd := -1;

    if not LStderrEOF then
    begin
      LPollFds[1].fd := AStderrFd;
      LPollFds[1].events := POLLIN;
      LAnyOpen := True;
    end
    else
      LPollFds[1].fd := -1;

    if not LAnyOpen then
      Break;

    LRet := poll(@LPollFds[0], 2, -1);
    if LRet < 0 then
    begin
      if platform_get_errno = ESysEINTR then
        Continue;
      Exit(platform_get_errno);
    end;
    if LRet = 0 then
      Continue;

    { Read stdout }
    if (LPollFds[0].revents and (POLLIN or POLLHUP or POLLERR)) <> 0 then
    begin
      if AStdoutLen < AStdoutBufLen then
        LN := read(AStdoutFd, @AStdoutBuf[AStdoutLen],
          AStdoutBufLen - AStdoutLen)
      else
        LN := read(AStdoutFd, @LDiscard[0], SizeOf(LDiscard));
      if LN < 0 then
      begin
        if platform_get_errno <> ESysEAGAIN then
          Exit(platform_get_errno);
      end
      else if LN = 0 then
        LStdoutEOF := True
      else if AStdoutLen < AStdoutBufLen then
        Inc(AStdoutLen, Int32(LN));
    end;

    { Read stderr }
    if (LPollFds[1].revents and (POLLIN or POLLHUP or POLLERR)) <> 0 then
    begin
      if AStderrLen < AStderrBufLen then
        LN := read(AStderrFd, @AStderrBuf[AStderrLen],
          AStderrBufLen - AStderrLen)
      else
        LN := read(AStderrFd, @LDiscard[0], SizeOf(LDiscard));
      if LN < 0 then
      begin
        if platform_get_errno <> ESysEAGAIN then
          Exit(platform_get_errno);
      end
      else if LN = 0 then
        LStderrEOF := True
      else if AStderrLen < AStderrBufLen then
        Inc(AStderrLen, Int32(LN));
    end;
  until False;

  if AStdoutLen < AStdoutBufLen then
    AStdoutBuf[AStdoutLen] := #0;
  if AStderrLen < AStderrBufLen then
    AStderrBuf[AStderrLen] := #0;
  Result := 0;
end;

function platform_process_run_capture(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar;
  AStdoutBuf: PAnsiChar; AStdoutBufLen: Int32; out AStdoutLen: Int32;
  AStderrBuf: PAnsiChar; AStderrBufLen: Int32; out AStderrLen: Int32;
  out AExitCode: Int32): Int32;
var
  LProc: TPlatformProcess;
  LResult: TPlatformProcessResult;
  LStdoutPipe, LStderrPipe: array[0..1] of Int32;
  LDevNullRead: Int32;
  LFailStage: TPlatformProcessSpawnStage;
begin
  AStdoutLen := 0;
  AStderrLen := 0;
  AExitCode := -1;
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  if IsInvalidOutputBuffer(AStdoutBuf, AStdoutBufLen) or
     IsInvalidOutputBuffer(AStderrBuf, AStderrBufLen) then
    Exit(PLATFORM_ERR_INVALID);
  LStdoutPipe[0] := -1; LStdoutPipe[1] := -1;
  LStderrPipe[0] := -1; LStderrPipe[1] := -1;
  LDevNullRead := -1;

  if pipe(@LStdoutPipe[0]) <> 0 then
    Exit(platform_get_errno);
  if pipe(@LStderrPipe[0]) <> 0 then
  begin
    Result := platform_get_errno;
    close(LStdoutPipe[0]); close(LStdoutPipe[1]);
    Exit;
  end;
  LDevNullRead := open('/dev/null', 0, 0);
  if LDevNullRead < 0 then
  begin
    Result := platform_get_errno;
    close(LStdoutPipe[0]); close(LStdoutPipe[1]);
    close(LStderrPipe[0]); close(LStderrPipe[1]);
    Exit;
  end;

  Result := platform_process_spawn_fds(APath, AArgv, nil, ACwd, LDevNullRead,
    LStdoutPipe[1], LStderrPipe[1], LProc, LFailStage);
  close(LDevNullRead);
  close(LStdoutPipe[1]);
  close(LStderrPipe[1]);
  if Result <> 0 then
  begin
    close(LStdoutPipe[0]);
    close(LStderrPipe[0]);
    Exit;
  end;

  try
    Result := ReadTwoPipes(LStdoutPipe[0], LStderrPipe[0],
      AStdoutBuf, AStdoutBufLen, AStdoutLen,
      AStderrBuf, AStderrBufLen, AStderrLen);
    if Result <> 0 then
      Exit;
  finally
    close(LStdoutPipe[0]);
    close(LStderrPipe[0]);
  end;

  Result := platform_process_wait(LProc, LResult);
  if Result = 0 then
    AExitCode := LResult.ExitCode;
end;

function platform_process_run_exec(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar;
  AStdoutBuf: PAnsiChar; AStdoutBufLen: Int32;
  AStderrBuf: PAnsiChar; AStderrBufLen: Int32;
  out AResult: TPlatformProcessExecResult): Int32;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  AResult.ExitCode := -1;
  AResult.Stdout := AStdoutBuf;
  AResult.Stderr := AStderrBuf;
  if (AStdoutBuf <> nil) and (AStdoutBufLen > 0) and
     (AStderrBuf <> nil) and (AStderrBufLen > 0) then
    Result := platform_process_run_capture(APath, AArgv, ACwd,
      AStdoutBuf, AStdoutBufLen, AResult.StdoutLen,
      AStderrBuf, AStderrBufLen, AResult.StderrLen,
      AResult.ExitCode)
  else if (AStdoutBuf <> nil) and (AStdoutBufLen > 0) then
  begin
    AResult.StderrLen := 0;
    Result := platform_process_run(APath, AArgv, ACwd,
      AStdoutBuf, AStdoutBufLen, AResult.StdoutLen,
      AResult.ExitCode);
  end
  else
  begin
    AResult.StdoutLen := 0;
    AResult.StderrLen := 0;
    { No capture requested, just spawn and wait }
    Result := platform_process_run(APath, AArgv, ACwd,
      nil, 0, AResult.StdoutLen,
      AResult.ExitCode);
  end;
end;

function platform_process_create_piped(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar; AOptions: TPlatformProcessOptions;
  out AProc: TPlatformProcess; out APipes: TPlatformProcessPipes): Int32;
var
  LStdinPipe, LStdoutPipe, LStderrPipe: array[0..1] of PtrInt;
  LDevNullRead, LDevNullWrite: PtrInt;
  LFailStage: TPlatformProcessSpawnStage;
  LChildStdin, LChildStdout, LChildStderr: PtrInt;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  FillChar(APipes, SizeOf(APipes), 0);
  APipes.StdinWrite := -1;
  APipes.StdoutRead := -1;
  APipes.StderrRead := -1;
  LStdinPipe[0] := -1; LStdinPipe[1] := -1;
  LStdoutPipe[0] := -1; LStdoutPipe[1] := -1;
  LStderrPipe[0] := -1; LStderrPipe[1] := -1;
  LDevNullRead := -1;
  LDevNullWrite := -1;

  { Create pipes based on options }
  if poRedirectStdin in AOptions then
  begin
    if platform_process_create_pipe(PtrInt(LStdinPipe[0]), PtrInt(LStdinPipe[1])) <> 0 then
      Exit(platform_get_errno);
  end;

  if poCaptureStdout in AOptions then
  begin
    if platform_process_create_pipe(PtrInt(LStdoutPipe[0]), PtrInt(LStdoutPipe[1])) <> 0 then
    begin
      if LStdinPipe[0] >= 0 then platform_process_close_handle(PtrInt(LStdinPipe[0]));
      if LStdinPipe[1] >= 0 then platform_process_close_handle(PtrInt(LStdinPipe[1]));
      Exit(platform_get_errno);
    end;
  end;

  if poCaptureStderr in AOptions then
  begin
    if platform_process_create_pipe(PtrInt(LStderrPipe[0]), PtrInt(LStderrPipe[1])) <> 0 then
    begin
      if LStdinPipe[0] >= 0 then platform_process_close_handle(PtrInt(LStdinPipe[0]));
      if LStdinPipe[1] >= 0 then platform_process_close_handle(PtrInt(LStdinPipe[1]));
      if LStdoutPipe[0] >= 0 then platform_process_close_handle(PtrInt(LStdoutPipe[0]));
      if LStdoutPipe[1] >= 0 then platform_process_close_handle(PtrInt(LStdoutPipe[1]));
      Exit(platform_get_errno);
    end;
  end;

  { Prepare child fd mapping }
  if poRedirectStdin in AOptions then
    LChildStdin := PtrInt(LStdinPipe[0])
  else
    LChildStdin := -1;

  if poCaptureStdout in AOptions then
    LChildStdout := PtrInt(LStdoutPipe[1])
  else
    LChildStdout := -1;

  if poCaptureStderr in AOptions then
    LChildStderr := PtrInt(LStderrPipe[1])
  else
    LChildStderr := -1;

  { Open /dev/null for non-captured streams }
  if not (poRedirectStdin in AOptions) then
  begin
    LDevNullRead := -1;
    platform_process_open_null(False, LDevNullRead);
    LChildStdin := LDevNullRead;
  end;
  if not (poCaptureStdout in AOptions) then
  begin
    LDevNullWrite := -1;
    platform_process_open_null(True, LDevNullWrite);
    LChildStdout := LDevNullWrite;
  end;
  if not (poCaptureStderr in AOptions) then
  begin
    if LDevNullWrite < 0 then
      platform_process_open_null(True, LDevNullWrite);
    LChildStderr := LDevNullWrite;
  end;

  Result := platform_process_spawn_fds(APath, AArgv, nil, ACwd,
    LChildStdin, LChildStdout, LChildStderr,
    AProc, LFailStage);

  { Close child-side fds and /dev/null handles }
  if LDevNullRead >= 0 then platform_process_close_handle(LDevNullRead);
  if LDevNullWrite >= 0 then platform_process_close_handle(LDevNullWrite);
  if LStdinPipe[0] >= 0 then platform_process_close_handle(PtrInt(LStdinPipe[0]));
  if LStdoutPipe[1] >= 0 then platform_process_close_handle(PtrInt(LStdoutPipe[1]));
  if LStderrPipe[1] >= 0 then platform_process_close_handle(PtrInt(LStderrPipe[1]));

  if Result <> 0 then
  begin
    { Cleanup parent-side fds on failure }
    if LStdinPipe[1] >= 0 then platform_process_close_handle(PtrInt(LStdinPipe[1]));
    if LStdoutPipe[0] >= 0 then platform_process_close_handle(PtrInt(LStdoutPipe[0]));
    if LStderrPipe[0] >= 0 then platform_process_close_handle(PtrInt(LStderrPipe[0]));
    Exit;
  end;

  { Return parent-side fds }
  if poRedirectStdin in AOptions then
    APipes.StdinWrite := PtrInt(LStdinPipe[1]);
  if poCaptureStdout in AOptions then
    APipes.StdoutRead := PtrInt(LStdoutPipe[0]);
  if poCaptureStderr in AOptions then
    APipes.StderrRead := PtrInt(LStderrPipe[0]);
end;

function platform_process_write_stdin_ex(AStdinWrite: PtrInt;
  AData: PAnsiChar; ALen: Int32; out ABytesWritten: Int32): Int32;
var
  LN: PtrInt;
begin
  ABytesWritten := 0;
  if (AStdinWrite < 0) or (ALen < 0) or ((AData = nil) and (ALen > 0)) then
    Exit(PLATFORM_ERR_INVALID);
  if ALen = 0 then
    Exit(0);
  LN := write(cint(AStdinWrite), AData, ALen);
  if LN < 0 then
    Exit(platform_get_errno);
  ABytesWritten := Int32(LN);
  Result := 0;
end;

function platform_process_read_stdout_ex(AStdoutRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;
var
  LN: PtrInt;
begin
  ABytesRead := 0;
  if (AStdoutRead < 0) or (ABufLen < 0) or ((ABuf = nil) and (ABufLen > 0)) then
    Exit(PLATFORM_ERR_INVALID);
  if ABufLen = 0 then
    Exit(0);
  LN := read(cint(AStdoutRead), ABuf, ABufLen);
  if LN < 0 then
  begin
    if platform_get_errno = ESysEAGAIN then
      Exit(0);
    Exit(platform_get_errno);
  end;
  ABytesRead := Int32(LN);
  Result := 0;
end;

function platform_process_read_stderr_ex(AStderrRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;
var
  LN: PtrInt;
begin
  ABytesRead := 0;
  if (AStderrRead < 0) or (ABufLen < 0) or ((ABuf = nil) and (ABufLen > 0)) then
    Exit(PLATFORM_ERR_INVALID);
  if ABufLen = 0 then
    Exit(0);
  LN := read(cint(AStderrRead), ABuf, ABufLen);
  if LN < 0 then
  begin
    if platform_get_errno = ESysEAGAIN then
      Exit(0);
    Exit(platform_get_errno);
  end;
  ABytesRead := Int32(LN);
  Result := 0;
end;

function LegacyProcessPipeIoResult(AError, ABytes: Int32): Int32; inline;
begin
  if AError = 0 then
    Exit(ABytes);
  if AError = PLATFORM_ERR_UNSUPPORTED then
    Exit(AError);
  Result := -1;
end;

function platform_process_write_stdin(AStdinWrite: PtrInt;
  AData: PAnsiChar; ALen: Int32): Int32; deprecated 'Use platform_process_write_stdin_ex';
var
  LError: Int32;
  LBytesWritten: Int32;
begin
  if (AStdinWrite < 0) or (AData = nil) or (ALen <= 0) then
    Exit(-1);
  LError := platform_process_write_stdin_ex(AStdinWrite, AData, ALen,
    LBytesWritten);
  Result := LegacyProcessPipeIoResult(LError, LBytesWritten);
end;

function platform_process_read_stdout(AStdoutRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32): Int32; deprecated 'Use platform_process_read_stdout_ex';
var
  LError: Int32;
  LBytesRead: Int32;
begin
  if (AStdoutRead < 0) or (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  LError := platform_process_read_stdout_ex(AStdoutRead, ABuf, ABufLen,
    LBytesRead);
  Result := LegacyProcessPipeIoResult(LError, LBytesRead);
end;

function platform_process_read_stderr(AStderrRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32): Int32; deprecated 'Use platform_process_read_stderr_ex';
var
  LError: Int32;
  LBytesRead: Int32;
begin
  if (AStderrRead < 0) or (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  LError := platform_process_read_stderr_ex(AStderrRead, ABuf, ABufLen,
    LBytesRead);
  Result := LegacyProcessPipeIoResult(LError, LBytesRead);
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi,
  nextpas.core.platform.windows.utf16,
  nextpas.core.platform.error;

const
  { Mirrors nextpas.core.platform.signal.PLATFORM_SIGKILL (contract number 9).
    Windows process path does not uses signal unit to avoid pulling console-handler deps. }
  PLATFORM_SIGKILL = 9;

function IsInvalidOutputBuffer(ABuf: PAnsiChar; ABufLen: Int32): Boolean; inline;
begin
  Result := (ABufLen < 0) or ((ABuf = nil) and (ABufLen > 0));
end;

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
    Exit(PLATFORM_ERR_INVALID);

  LCwdPtr := nil;
  if ACwd <> nil then
  begin
    if not platform_windows_utf8_to_wide_checked(ACwd, LCwd) then
      Exit(PLATFORM_ERR_INVALID);
    LCwdPtr := PWideChar(LCwd);
  end;

  LEnvPtr := nil;
  if AEnvp <> nil then
  begin
    if not platform_windows_envp_to_wide_block(AEnvp, LEnvBlock) then
      Exit(PLATFORM_ERR_INVALID);
    LEnvPtr := PWideChar(LEnvBlock);
  end;

  LCreationFlags := ACreationFlags;
  if AEnvp <> nil then
    LCreationFlags := LCreationFlags or CREATE_UNICODE_ENVIRONMENT;
  if not CreateProcessW(nil, PWideChar(LCmd), nil, nil, AInheritHandles,
    LCreationFlags, LEnvPtr, LCwdPtr, @AStartupInfo,
    @AProcessInfo) then
    Exit(platform_get_last_error);
  Result := 0;
end;

function CreateWindowsJobForProcess(var AProc: TPlatformProcess): Boolean;
var
  LJob: HANDLE;
begin
  Result := False;
  AProc.JobHandle := 0;
  LJob := CreateJobObjectW(nil, nil);
  if (LJob = nil) or (LJob = HANDLE(PtrInt(-1))) then
    Exit;
  if not AssignProcessToJobObject(LJob, HANDLE(AProc.ProcessHandle)) then
  begin
    CloseHandle(LJob);
    Exit;
  end;
  AProc.JobHandle := PtrUInt(LJob);
  Result := True;
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

function platform_process_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult; ATimeoutMs: Int64): Int32;
var
  LExitCode, LTimeout, LWait: DWORD;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  if ATimeoutMs <= 0 then
    LTimeout := $FFFFFFFF { INFINITE }
  else
    LTimeout := DWORD(ATimeoutMs);
  LWait := WaitForSingleObject(HANDLE(AProc.ProcessHandle), LTimeout);
  if LWait = $00000102 then
  begin
    { WAIT_TIMEOUT: process still running }
    AResult.Status := psRunning;
    Exit(PLATFORM_ERR_TIMEDOUT);
  end;
  if LWait <> 0 then
    Exit(platform_get_last_error);
  LExitCode := 0;
  if not GetExitCodeProcess(HANDLE(AProc.ProcessHandle), @LExitCode) then
    Exit(platform_get_last_error);
  AResult.Status := psExited;
  AResult.ExitCode := Int32(LExitCode);
  Result := 0;
end;

function platform_process_try_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult): Int32;
var
  LExitCode, LWait: DWORD;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  LWait := WaitForSingleObject(HANDLE(AProc.ProcessHandle), 0);
  if LWait = $00000102 then
  begin
    AResult.Status := psRunning;
    Exit(0);
  end;
  if LWait <> 0 then
    Exit(platform_get_last_error);
  LExitCode := 0;
  GetExitCodeProcess(HANDLE(AProc.ProcessHandle), @LExitCode);
  AResult.Status := psExited;
  AResult.ExitCode := Int32(LExitCode);
  Result := 0;
end;

procedure platform_process_detach(var AProc: TPlatformProcess);
begin
  if AProc.JobHandle <> 0 then
  begin
    CloseHandle(HANDLE(AProc.JobHandle));
    AProc.JobHandle := 0;
  end;
  if AProc.ProcessHandle <> 0 then
    CloseHandle(HANDLE(AProc.ProcessHandle));
  AProc.ProcessHandle := 0;
  AProc.ThreadHandle := 0;
end;

function platform_process_signal(const AProc: TPlatformProcess; ASignal: Int32): Int32;
begin
  if ASignal = PLATFORM_SIGKILL then
  begin
    { M2-W2: Job Object kills process tree when NewProcessGroup was used. }
    if AProc.JobHandle <> 0 then
    begin
      if TerminateJobObject(HANDLE(AProc.JobHandle), 1) then
        Result := 0
      else
        Result := platform_get_last_error;
    end
    else if TerminateProcess(HANDLE(AProc.ProcessHandle), 1) then
      Result := 0
    else
      Result := platform_get_last_error;
  end
  else
    Result := PLATFORM_ERR_UNSUPPORTED;
end;

function platform_process_kill(const AProc: TPlatformProcess): Int32;
begin
  Result := platform_process_signal(AProc, PLATFORM_SIGKILL);
end;

function platform_process_kill_group(APgid: Int32; ASignal: Int32): Int32;
begin
  { Windows has no POSIX pgid; KillTree uses platform_process_kill with JobHandle. }
  Result := PLATFORM_ERR_UNSUPPORTED;
end;

function platform_process_pid(const AProc: TPlatformProcess): Int32;
begin Result := Int32(AProc.Pid); end;

function platform_process_create_pipe(out AReadHandle, AWriteHandle: PtrInt): Int32;
var
  LReadHandle, LWriteHandle: HANDLE;
  LSA: SECURITY_ATTRIBUTES;
begin
  AReadHandle := -1;
  AWriteHandle := -1;
  FillChar(LSA, SizeOf(LSA), 0);
  LSA.nLength := SizeOf(LSA);
  LSA.bInheritHandle := True;
  if not CreatePipe(@LReadHandle, @LWriteHandle, @LSA, 0) then
    Exit(platform_get_last_error);
  AReadHandle := PtrInt(PtrUInt(LReadHandle));
  AWriteHandle := PtrInt(PtrUInt(LWriteHandle));
  Result := 0;
end;

function platform_process_open_null(const AForWrite: Boolean; out AHandle: PtrInt): Int32;
var
  LNulPath: UnicodeString;
  LAccess: DWORD;
  LHandle: HANDLE;
begin
  AHandle := -1;
  LNulPath := 'NUL';
  if AForWrite then
    LAccess := GENERIC_WRITE
  else
    LAccess := GENERIC_READ;
  LHandle := CreateFileW(PWideChar(LNulPath), LAccess,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, nil);
  if LHandle = HANDLE(PtrInt(-1)) then
    Exit(platform_get_last_error);
  AHandle := PtrInt(PtrUInt(LHandle));
  Result := 0;
end;

function platform_process_close_handle(var AHandle: PtrInt): Int32;
begin
  if AHandle < 0 then
    Exit(0);
  if not CloseHandle(HANDLE(PtrUInt(AHandle))) then
    Exit(platform_get_last_error);
  AHandle := -1;
  Result := 0;
end;

function platform_process_set_handle_inheritable(AHandle: PtrInt;
  AInherit: Boolean): Int32;
var
  LFlags: DWORD;
begin
  if AHandle < 0 then
    Exit(PLATFORM_ERR_INVALID);
  if AInherit then
    LFlags := HANDLE_FLAG_INHERIT
  else
    LFlags := 0;
  if not SetHandleInformation(HANDLE(PtrUInt(AHandle)), HANDLE_FLAG_INHERIT,
    LFlags) then
    Exit(platform_get_last_error);
  Result := 0;
end;

function platform_process_spawn_fds(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  AChildStdin, AChildStdout, AChildStderr: PtrInt;
  out AProc: TPlatformProcess;
  out AFailStage: TPlatformProcessSpawnStage): Int32;
begin
  Result := platform_process_spawn_fds_ex(APath, AArgv, AEnvp, ACwd,
    AChildStdin, AChildStdout, AChildStderr, nil, 0, False, 0, 0, False,
    AProc, AFailStage);
end;

function platform_process_spawn_fds_ex(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; const ACwd: PAnsiChar;
  AChildStdin, AChildStdout, AChildStderr: PtrInt;
  AExtraFds: PPtrInt; AExtraFdCount: Int32;
  ASetCred: Boolean; AUid, AGid: UInt32;
  ANewProcessGroup: Boolean;
  out AProc: TPlatformProcess;
  out AFailStage: TPlatformProcessSpawnStage): Int32;
var
  LSI: STARTUPINFOW;
  LPI: PROCESS_INFORMATION;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  AFailStage := pssNone;

  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  { ExtraFd / Credential still unsupported on Windows. NewProcessGroup uses Job Object. }
  if (AExtraFdCount > 0) or ASetCred then
  begin
    AFailStage := pssExec;
    Exit(PLATFORM_ERR_UNSUPPORTED);
  end;

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

  if ANewProcessGroup then
    Result := CreateWindowsProcess(APath, AArgv, AEnvp, ACwd, True,
      CREATE_SUSPENDED, LSI, LPI)
  else
    Result := CreateWindowsProcess(APath, AArgv, AEnvp, ACwd, True, 0, LSI, LPI);
  if Result <> 0 then
  begin
    AFailStage := pssExec;
    Exit;
  end;
  AProc.ProcessHandle := PtrUInt(LPI.hProcess);
  AProc.ThreadHandle := PtrUInt(LPI.hThread);
  AProc.Pid := LPI.dwProcessId;
  AProc.JobHandle := 0;

  if ANewProcessGroup then
  begin
    { M2-W2: Job Object as process-tree container (Go-ish tree kill). }
    if not CreateWindowsJobForProcess(AProc) then
    begin
      Result := platform_get_last_error;
      if Result = 0 then
        Result := PLATFORM_ERR_UNKNOWN;
      TerminateProcess(HANDLE(AProc.ProcessHandle), 1);
      CloseHandle(LPI.hThread);
      CloseHandle(LPI.hProcess);
      FillChar(AProc, SizeOf(AProc), 0);
      AFailStage := pssExec;
      Exit;
    end;
    if ResumeThread(LPI.hThread) = DWORD($FFFFFFFF) then
    begin
      Result := platform_get_last_error;
      if AProc.JobHandle <> 0 then
      begin
        TerminateJobObject(HANDLE(AProc.JobHandle), 1);
        CloseHandle(HANDLE(AProc.JobHandle));
      end;
      CloseHandle(LPI.hThread);
      CloseHandle(LPI.hProcess);
      FillChar(AProc, SizeOf(AProc), 0);
      AFailStage := pssExec;
      Exit;
    end;
  end;

  CloseHandle(HANDLE(AProc.ThreadHandle));
  AProc.ThreadHandle := 0;
  Result := 0;
end;

function platform_process_run(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar; AOutBuf: PAnsiChar; AOutBufLen: Int32;
  out AOutLen: Int32; out AExitCode: Int32): Int32;
var
  LProc: TPlatformProcess;
  LResult: TPlatformProcessResult;
  LStdoutRd, LStdoutWr: HANDLE;
  LDevNullRead, LDevNullWrite: HANDLE;
  LSA: SECURITY_ATTRIBUTES;
  LFailStage: TPlatformProcessSpawnStage;
  LNulPath: UnicodeString;
  LRead: DWORD;
  LTotal: Int32;
  LDiscard: array[0..4095] of Byte;
begin
  AOutLen := 0;
  AExitCode := -1;
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  if IsInvalidOutputBuffer(AOutBuf, AOutBufLen) then
    Exit(PLATFORM_ERR_INVALID);
  LStdoutRd := HANDLE(PtrInt(-1));
  LStdoutWr := HANDLE(PtrInt(-1));
  LDevNullRead := HANDLE(PtrInt(-1));
  LDevNullWrite := HANDLE(PtrInt(-1));

  FillChar(LSA, SizeOf(LSA), 0);
  LSA.nLength := SizeOf(LSA);
  LSA.bInheritHandle := True;
  if not CreatePipe(@LStdoutRd, @LStdoutWr, @LSA, 0) then
    Exit(platform_get_last_error);
  if not SetHandleInformation(LStdoutRd, HANDLE_FLAG_INHERIT, 0) then
  begin
    Result := platform_get_last_error;
    CloseHandle(LStdoutRd);
    CloseHandle(LStdoutWr);
    Exit;
  end;

  LNulPath := 'NUL';
  LDevNullRead := CreateFileW(PWideChar(LNulPath), GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE, @LSA, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, nil);
  if LDevNullRead = HANDLE(PtrInt(-1)) then
  begin
    Result := platform_get_last_error;
    CloseHandle(LStdoutRd);
    CloseHandle(LStdoutWr);
    Exit;
  end;
  LDevNullWrite := CreateFileW(PWideChar(LNulPath), GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE, @LSA, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, nil);
  if LDevNullWrite = HANDLE(PtrInt(-1)) then
  begin
    Result := platform_get_last_error;
    CloseHandle(LDevNullRead);
    CloseHandle(LStdoutRd);
    CloseHandle(LStdoutWr);
    Exit;
  end;

  Result := platform_process_spawn_fds(APath, AArgv, nil, ACwd,
    PtrInt(PtrUInt(LDevNullRead)), PtrInt(PtrUInt(LStdoutWr)),
    PtrInt(PtrUInt(LDevNullWrite)), LProc, LFailStage);
  CloseHandle(LDevNullRead);
  CloseHandle(LDevNullWrite);
  CloseHandle(LStdoutWr);
  if Result <> 0 then
  begin
    CloseHandle(LStdoutRd);
    Exit;
  end;

  try
    LTotal := 0;
    repeat
      LRead := 0;
      if LTotal < AOutBufLen then
      begin
        if not ReadFile(LStdoutRd, @AOutBuf[LTotal],
          DWORD(AOutBufLen - LTotal), @LRead, nil) then
          Break;
        if LRead > 0 then
          Inc(LTotal, Int32(LRead));
      end
      else if not ReadFile(LStdoutRd, @LDiscard[0],
        DWORD(SizeOf(LDiscard)), @LRead, nil) then
        Break;
      if LRead = 0 then Break;
    until False;
    if LTotal < AOutBufLen then
      AOutBuf[LTotal] := #0;
    AOutLen := LTotal;
  finally
    CloseHandle(LStdoutRd);
  end;

  Result := platform_process_wait(LProc, LResult);
  if Result = 0 then
    AExitCode := LResult.ExitCode;
end;

function platform_process_run_capture(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar;
  AStdoutBuf: PAnsiChar; AStdoutBufLen: Int32; out AStdoutLen: Int32;
  AStderrBuf: PAnsiChar; AStderrBufLen: Int32; out AStderrLen: Int32;
  out AExitCode: Int32): Int32;
var
  LProc: TPlatformProcess;
  LResult: TPlatformProcessResult;
  LStdoutRd, LStdoutWr: HANDLE;
  LStderrRd, LStderrWr: HANDLE;
  LDevNullRead: HANDLE;
  LSA: SECURITY_ATTRIBUTES;
  LFailStage: TPlatformProcessSpawnStage;
  LNulPath: UnicodeString;
  LRead, LAvail, LErr: DWORD;
  LDiscard: array[0..4095] of Byte;
  LStdoutDone, LStderrDone: Boolean;
  LWaited: Boolean;
  LPrevOut, LPrevErr: Int32;

  procedure CloseIfValid(var AH: HANDLE);
  begin
    if AH <> HANDLE(PtrInt(-1)) then
    begin
      CloseHandle(AH);
      AH := HANDLE(PtrInt(-1));
    end;
  end;

  { Non-blocking drain of available bytes. ADone on EOF/broken pipe. }
  function TryDrain(ARd: HANDLE; ABuf: PAnsiChar; ABufLen: Int32;
    var ALen: Int32; var ADone: Boolean; AAllowBlockingEof: Boolean): Boolean;
  begin
    Result := True;
    if ADone then
      Exit;
    LAvail := 0;
    if not PeekNamedPipe(ARd, nil, 0, nil, @LAvail, nil) then
    begin
      LErr := GetLastError;
      if (LErr = ERROR_BROKEN_PIPE) or (LErr = ERROR_HANDLE_EOF) then
        ADone := True
      else
        Result := False;
      Exit;
    end;
    if LAvail = 0 then
    begin
      { Only blocking-read for EOF after child has exited (writers closed). }
      if not AAllowBlockingEof then
        Exit;
      LRead := 0;
      if not ReadFile(ARd, @LDiscard[0], 1, @LRead, nil) then
      begin
        LErr := GetLastError;
        if (LErr = ERROR_BROKEN_PIPE) or (LErr = ERROR_HANDLE_EOF) then
          ADone := True
        else
          Result := False;
        Exit;
      end;
      if LRead = 0 then
      begin
        ADone := True;
        Exit;
      end;
      { Got 1 leftover byte }
      if ALen < ABufLen then
      begin
        ABuf[ALen] := AnsiChar(LDiscard[0]);
        Inc(ALen);
      end;
      Exit;
    end;
    while LAvail > 0 do
    begin
      LRead := 0;
      if ALen < ABufLen then
      begin
        if not ReadFile(ARd, @ABuf[ALen], DWORD(ABufLen - ALen), @LRead, nil) then
        begin
          LErr := GetLastError;
          if (LErr = ERROR_BROKEN_PIPE) or (LErr = ERROR_HANDLE_EOF) then
            ADone := True
          else
            Result := False;
          Exit;
        end;
        if LRead = 0 then
        begin
          ADone := True;
          Exit;
        end;
        Inc(ALen, Int32(LRead));
      end
      else
      begin
        if not ReadFile(ARd, @LDiscard[0], DWORD(SizeOf(LDiscard)), @LRead, nil) then
        begin
          LErr := GetLastError;
          if (LErr = ERROR_BROKEN_PIPE) or (LErr = ERROR_HANDLE_EOF) then
            ADone := True
          else
            Result := False;
          Exit;
        end;
        if LRead = 0 then
        begin
          ADone := True;
          Exit;
        end;
      end;
      if not PeekNamedPipe(ARd, nil, 0, nil, @LAvail, nil) then
      begin
        LErr := GetLastError;
        if (LErr = ERROR_BROKEN_PIPE) or (LErr = ERROR_HANDLE_EOF) then
          ADone := True
        else
          Result := False;
        Exit;
      end;
    end;
  end;

begin
  AStdoutLen := 0;
  AStderrLen := 0;
  AExitCode := -1;
  if APath = nil then
    Exit(PLATFORM_ERR_INVALID);
  if IsInvalidOutputBuffer(AStdoutBuf, AStdoutBufLen) or
     IsInvalidOutputBuffer(AStderrBuf, AStderrBufLen) then
    Exit(PLATFORM_ERR_INVALID);

  LStdoutRd := HANDLE(PtrInt(-1));
  LStdoutWr := HANDLE(PtrInt(-1));
  LStderrRd := HANDLE(PtrInt(-1));
  LStderrWr := HANDLE(PtrInt(-1));
  LDevNullRead := HANDLE(PtrInt(-1));
  LWaited := False;

  FillChar(LSA, SizeOf(LSA), 0);
  LSA.nLength := SizeOf(LSA);
  LSA.bInheritHandle := True;

  if not CreatePipe(@LStdoutRd, @LStdoutWr, @LSA, 0) then
    Exit(platform_get_last_error);
  if not SetHandleInformation(LStdoutRd, HANDLE_FLAG_INHERIT, 0) then
  begin
    Result := platform_get_last_error;
    CloseIfValid(LStdoutRd);
    CloseIfValid(LStdoutWr);
    Exit;
  end;
  if not CreatePipe(@LStderrRd, @LStderrWr, @LSA, 0) then
  begin
    Result := platform_get_last_error;
    CloseIfValid(LStdoutRd);
    CloseIfValid(LStdoutWr);
    Exit;
  end;
  if not SetHandleInformation(LStderrRd, HANDLE_FLAG_INHERIT, 0) then
  begin
    Result := platform_get_last_error;
    CloseIfValid(LStdoutRd);
    CloseIfValid(LStdoutWr);
    CloseIfValid(LStderrRd);
    CloseIfValid(LStderrWr);
    Exit;
  end;

  LNulPath := 'NUL';
  LDevNullRead := CreateFileW(PWideChar(LNulPath), GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE, @LSA, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, nil);
  if LDevNullRead = HANDLE(PtrInt(-1)) then
  begin
    Result := platform_get_last_error;
    CloseIfValid(LStdoutRd);
    CloseIfValid(LStdoutWr);
    CloseIfValid(LStderrRd);
    CloseIfValid(LStderrWr);
    Exit;
  end;

  Result := platform_process_spawn_fds(APath, AArgv, nil, ACwd,
    PtrInt(PtrUInt(LDevNullRead)), PtrInt(PtrUInt(LStdoutWr)),
    PtrInt(PtrUInt(LStderrWr)), LProc, LFailStage);
  CloseIfValid(LDevNullRead);
  CloseIfValid(LStdoutWr);
  CloseIfValid(LStderrWr);
  if Result <> 0 then
  begin
    CloseIfValid(LStdoutRd);
    CloseIfValid(LStderrRd);
    Exit;
  end;

  LStdoutDone := False;
  LStderrDone := False;
  try
    while (not LStdoutDone) or (not LStderrDone) do
    begin
      LPrevOut := AStdoutLen;
      LPrevErr := AStderrLen;
      if not TryDrain(LStdoutRd, AStdoutBuf, AStdoutBufLen, AStdoutLen,
        LStdoutDone, LWaited) then
        Exit(platform_get_last_error);
      if not TryDrain(LStderrRd, AStderrBuf, AStderrBufLen, AStderrLen,
        LStderrDone, LWaited) then
        Exit(platform_get_last_error);
      if LStdoutDone and LStderrDone then
        Break;
      if not LWaited then
      begin
        if platform_process_try_wait(LProc, LResult) = 0 then
        begin
          if LResult.Status <> nextpas.core.platform.process.base.psRunning then
          begin
            LWaited := True;
            AExitCode := LResult.ExitCode;
          end;
        end;
      end;
      if (AStdoutLen = LPrevOut) and (AStderrLen = LPrevErr) then
        Sleep(1);
    end;
    if (AStdoutBuf <> nil) and (AStdoutLen < AStdoutBufLen) then
      AStdoutBuf[AStdoutLen] := #0;
    if (AStderrBuf <> nil) and (AStderrLen < AStderrBufLen) then
      AStderrBuf[AStderrLen] := #0;
  finally
    CloseIfValid(LStdoutRd);
    CloseIfValid(LStderrRd);
  end;

  if not LWaited then
  begin
    Result := platform_process_wait(LProc, LResult);
    if Result = 0 then
      AExitCode := LResult.ExitCode;
  end
  else
    Result := 0;
end;

function platform_process_run_exec(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar;
  AStdoutBuf: PAnsiChar; AStdoutBufLen: Int32;
  AStderrBuf: PAnsiChar; AStderrBufLen: Int32;
  out AResult: TPlatformProcessExecResult): Int32;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  AResult.ExitCode := -1;
  AResult.Stdout := AStdoutBuf;
  AResult.Stderr := AStderrBuf;
  if (AStdoutBuf <> nil) and (AStdoutBufLen > 0) and
     (AStderrBuf <> nil) and (AStderrBufLen > 0) then
    Result := platform_process_run_capture(APath, AArgv, ACwd,
      AStdoutBuf, AStdoutBufLen, AResult.StdoutLen,
      AStderrBuf, AStderrBufLen, AResult.StderrLen,
      AResult.ExitCode)
  else if (AStdoutBuf <> nil) and (AStdoutBufLen > 0) then
  begin
    AResult.StderrLen := 0;
    Result := platform_process_run(APath, AArgv, ACwd,
      AStdoutBuf, AStdoutBufLen, AResult.StdoutLen,
      AResult.ExitCode);
  end
  else
  begin
    AResult.StdoutLen := 0;
    AResult.StderrLen := 0;
    Result := platform_process_run(APath, AArgv, ACwd,
      nil, 0, AResult.StdoutLen,
      AResult.ExitCode);
  end;
end;

function platform_process_create_piped(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar; AOptions: TPlatformProcessOptions;
  out AProc: TPlatformProcess; out APipes: TPlatformProcessPipes): Int32;
var
  LStdinPipe, LStdoutPipe, LStderrPipe: array[0..1] of PtrInt;
  LDevNullRead, LDevNullWrite: PtrInt;
  LFailStage: TPlatformProcessSpawnStage;
  LChildStdin, LChildStdout, LChildStderr: PtrInt;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  FillChar(APipes, SizeOf(APipes), 0);
  APipes.StdinWrite := -1;
  APipes.StdoutRead := -1;
  APipes.StderrRead := -1;
  LStdinPipe[0] := -1; LStdinPipe[1] := -1;
  LStdoutPipe[0] := -1; LStdoutPipe[1] := -1;
  LStderrPipe[0] := -1; LStderrPipe[1] := -1;
  LDevNullRead := -1;
  LDevNullWrite := -1;

  { Create pipes based on options }
  if poRedirectStdin in AOptions then
  begin
    if platform_process_create_pipe(LStdinPipe[0], LStdinPipe[1]) <> 0 then
      Exit(platform_get_errno);
  end;

  if poCaptureStdout in AOptions then
  begin
    if platform_process_create_pipe(LStdoutPipe[0], LStdoutPipe[1]) <> 0 then
    begin
      if LStdinPipe[0] >= 0 then platform_process_close_handle(LStdinPipe[0]);
      if LStdinPipe[1] >= 0 then platform_process_close_handle(LStdinPipe[1]);
      Exit(platform_get_errno);
    end;
  end;

  if poCaptureStderr in AOptions then
  begin
    if platform_process_create_pipe(LStderrPipe[0], LStderrPipe[1]) <> 0 then
    begin
      if LStdinPipe[0] >= 0 then platform_process_close_handle(LStdinPipe[0]);
      if LStdinPipe[1] >= 0 then platform_process_close_handle(LStdinPipe[1]);
      if LStdoutPipe[0] >= 0 then platform_process_close_handle(LStdoutPipe[0]);
      if LStdoutPipe[1] >= 0 then platform_process_close_handle(LStdoutPipe[1]);
      Exit(platform_get_errno);
    end;
  end;

  { Prepare child fd mapping }
  if poRedirectStdin in AOptions then
    LChildStdin := LStdinPipe[0]
  else
    LChildStdin := -1;

  if poCaptureStdout in AOptions then
    LChildStdout := LStdoutPipe[1]
  else
    LChildStdout := -1;

  if poCaptureStderr in AOptions then
    LChildStderr := LStderrPipe[1]
  else
    LChildStderr := -1;

  { Open NUL for non-captured streams }
  if not (poRedirectStdin in AOptions) then
  begin
    platform_process_open_null(False, LDevNullRead);
    LChildStdin := LDevNullRead;
  end;
  if not (poCaptureStdout in AOptions) then
  begin
    platform_process_open_null(True, LDevNullWrite);
    LChildStdout := LDevNullWrite;
  end;
  if not (poCaptureStderr in AOptions) then
  begin
    if LDevNullWrite < 0 then
      platform_process_open_null(True, LDevNullWrite);
    LChildStderr := LDevNullWrite;
  end;

  Result := platform_process_spawn_fds(APath, AArgv, nil, ACwd,
    LChildStdin, LChildStdout, LChildStderr,
    AProc, LFailStage);

  { Close child-side fds and NUL handles }
  if LDevNullRead >= 0 then platform_process_close_handle(LDevNullRead);
  if LDevNullWrite >= 0 then platform_process_close_handle(LDevNullWrite);
  if LStdinPipe[0] >= 0 then platform_process_close_handle(LStdinPipe[0]);
  if LStdoutPipe[1] >= 0 then platform_process_close_handle(LStdoutPipe[1]);
  if LStderrPipe[1] >= 0 then platform_process_close_handle(LStderrPipe[1]);

  if Result <> 0 then
  begin
    { Cleanup parent-side fds on failure }
    if LStdinPipe[1] >= 0 then platform_process_close_handle(LStdinPipe[1]);
    if LStdoutPipe[0] >= 0 then platform_process_close_handle(LStdoutPipe[0]);
    if LStderrPipe[0] >= 0 then platform_process_close_handle(LStderrPipe[0]);
    Exit;
  end;

  { Return parent-side fds }
  if poRedirectStdin in AOptions then
    APipes.StdinWrite := LStdinPipe[1];
  if poCaptureStdout in AOptions then
    APipes.StdoutRead := LStdoutPipe[0];
  if poCaptureStderr in AOptions then
    APipes.StderrRead := LStderrPipe[0];
end;

function platform_process_write_stdin_ex(AStdinWrite: PtrInt;
  AData: PAnsiChar; ALen: Int32; out ABytesWritten: Int32): Int32;
var
  LWritten: DWORD;
begin
  ABytesWritten := 0;
  if (AStdinWrite < 0) or (ALen < 0) or ((AData = nil) and (ALen > 0)) then
    Exit(PLATFORM_ERR_INVALID);
  if ALen = 0 then
    Exit(0);
  LWritten := 0;
  if not WriteFile(HANDLE(PtrUInt(AStdinWrite)), AData, DWORD(ALen), @LWritten, nil) then
    Exit(platform_get_last_error);
  ABytesWritten := Int32(LWritten);
  Result := 0;
end;

function platform_process_read_stdout_ex(AStdoutRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;
var
  LRead: DWORD;
  LError: DWORD;
begin
  ABytesRead := 0;
  if (AStdoutRead < 0) or (ABufLen < 0) or ((ABuf = nil) and (ABufLen > 0)) then
    Exit(PLATFORM_ERR_INVALID);
  if ABufLen = 0 then
    Exit(0);
  LRead := 0;
  if not ReadFile(HANDLE(PtrUInt(AStdoutRead)), ABuf, DWORD(ABufLen), @LRead, nil) then
  begin
    LError := GetLastError;
    if (LError = ERROR_BROKEN_PIPE) or (LError = ERROR_HANDLE_EOF) then
      Exit(0);
    Exit(platform_map_windows_error_code(LError));
  end;
  ABytesRead := Int32(LRead);
  Result := 0;
end;

function platform_process_read_stderr_ex(AStderrRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;
var
  LRead: DWORD;
  LError: DWORD;
begin
  ABytesRead := 0;
  if (AStderrRead < 0) or (ABufLen < 0) or ((ABuf = nil) and (ABufLen > 0)) then
    Exit(PLATFORM_ERR_INVALID);
  if ABufLen = 0 then
    Exit(0);
  LRead := 0;
  if not ReadFile(HANDLE(PtrUInt(AStderrRead)), ABuf, DWORD(ABufLen), @LRead, nil) then
  begin
    LError := GetLastError;
    if (LError = ERROR_BROKEN_PIPE) or (LError = ERROR_HANDLE_EOF) then
      Exit(0);
    Exit(platform_map_windows_error_code(LError));
  end;
  ABytesRead := Int32(LRead);
  Result := 0;
end;

function LegacyProcessPipeIoResult(AError, ABytes: Int32): Int32; inline;
begin
  if AError = 0 then
    Exit(ABytes);
  if AError = PLATFORM_ERR_UNSUPPORTED then
    Exit(AError);
  Result := -1;
end;

function platform_process_write_stdin(AStdinWrite: PtrInt;
  AData: PAnsiChar; ALen: Int32): Int32; deprecated 'Use platform_process_write_stdin_ex';
var
  LError: Int32;
  LBytesWritten: Int32;
begin
  if (AStdinWrite < 0) or (AData = nil) or (ALen <= 0) then
    Exit(-1);
  LError := platform_process_write_stdin_ex(AStdinWrite, AData, ALen,
    LBytesWritten);
  Result := LegacyProcessPipeIoResult(LError, LBytesWritten);
end;

function platform_process_read_stdout(AStdoutRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32): Int32; deprecated 'Use platform_process_read_stdout_ex';
var
  LError: Int32;
  LBytesRead: Int32;
begin
  if (AStdoutRead < 0) or (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  LError := platform_process_read_stdout_ex(AStdoutRead, ABuf, ABufLen,
    LBytesRead);
  Result := LegacyProcessPipeIoResult(LError, LBytesRead);
end;

function platform_process_read_stderr(AStderrRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32): Int32; deprecated 'Use platform_process_read_stderr_ex';
var
  LError: Int32;
  LBytesRead: Int32;
begin
  if (AStderrRead < 0) or (ABuf = nil) or (ABufLen <= 0) then
    Exit(-1);
  LError := platform_process_read_stderr_ex(AStderrRead, ABuf, ABufLen,
    LBytesRead);
  Result := LegacyProcessPipeIoResult(LError, LBytesRead);
end;

function platform_getpid: Int32;
begin
  Result := Int32(GetCurrentProcessId);
end;

function platform_io_read(AFd: PtrInt; ABuf: Pointer; ACount: SizeUInt): PtrInt;
var
  LRead: DWORD;
begin
  if (AFd < 0) or (ABuf = nil) or (ACount = 0) then
    Exit(-1);
  if not ReadFile(HANDLE(PtrUInt(AFd)), ABuf, DWORD(ACount), @LRead, nil) then
    Exit(-1);
  Result := PtrInt(LRead);
end;

function platform_io_write(AFd: PtrInt; ABuf: Pointer; ACount: SizeUInt): PtrInt;
var
  LWritten: DWORD;
begin
  if (AFd < 0) or (ABuf = nil) or (ACount = 0) then
    Exit(-1);
  if not WriteFile(HANDLE(PtrUInt(AFd)), ABuf, DWORD(ACount), @LWritten, nil) then
    Exit(-1);
  Result := PtrInt(LWritten);
end;

function platform_io_close(AFd: PtrInt): Int32;
begin
  if AFd < 0 then
    Exit(0);
  if CloseHandle(HANDLE(PtrUInt(AFd))) then
    Result := 0
  else
    Result := platform_get_last_error;
end;

function platform_io_poll(AFds: Pointer; ACount: Int32; ATimeoutMs: Int32): Int32;
begin
  { Windows uses WaitForMultipleObjects/IOCP, not poll.
    This stub exists for interface completeness. }
  Result := -1;
end;
{$ENDIF}

{$IF not defined(NEXTPAS_UNIX) and not defined(NEXTPAS_WINDOWS)}
function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
begin FillChar(AProc, SizeOf(AProc), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult; ATimeoutMs: Int64): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_try_wait(const AProc: TPlatformProcess; out AResult: TPlatformProcessResult): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
procedure platform_process_detach(var AProc: TPlatformProcess);
begin FillChar(AProc, SizeOf(AProc), 0); end;
function platform_process_signal(const AProc: TPlatformProcess; ASignal: Int32): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_kill(const AProc: TPlatformProcess): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_kill_group(APgid: Int32; ASignal: Int32): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_pid(const AProc: TPlatformProcess): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_create_pipe(out AReadHandle, AWriteHandle: PtrInt): Int32;
begin AReadHandle := -1; AWriteHandle := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_open_null(const AForWrite: Boolean; out AHandle: PtrInt): Int32;
begin AHandle := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_close_handle(var AHandle: PtrInt): Int32;
begin AHandle := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_set_handle_inheritable(AHandle: PtrInt;
  AInherit: Boolean): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_run(const APath: PAnsiChar; AArgv: PPAnsiChar; const ACwd: PAnsiChar; AOutBuf: PAnsiChar; AOutBufLen: Int32; out AOutLen: Int32; out AExitCode: Int32): Int32;
begin AOutLen := 0; AExitCode := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_spawn_fds(const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; const ACwd: PAnsiChar; AChildStdin, AChildStdout, AChildStderr: PtrInt; out AProc: TPlatformProcess; out AFailStage: TPlatformProcessSpawnStage): Int32;
begin FillChar(AProc, SizeOf(AProc), 0); AFailStage := pssNone; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_spawn_fds_ex(const APath: PAnsiChar; AArgv: PPAnsiChar; AEnvp: PPAnsiChar; const ACwd: PAnsiChar; AChildStdin, AChildStdout, AChildStderr: PtrInt; AExtraFds: PPtrInt; AExtraFdCount: Int32; ASetCred: Boolean; AUid, AGid: UInt32; ANewProcessGroup: Boolean; out AProc: TPlatformProcess; out AFailStage: TPlatformProcessSpawnStage): Int32;
begin FillChar(AProc, SizeOf(AProc), 0); AFailStage := pssNone; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_run_capture(const APath: PAnsiChar; AArgv: PPAnsiChar; const ACwd: PAnsiChar; AStdoutBuf: PAnsiChar; AStdoutBufLen: Int32; out AStdoutLen: Int32; AStderrBuf: PAnsiChar; AStderrBufLen: Int32; out AStderrLen: Int32; out AExitCode: Int32): Int32;
begin AStdoutLen := 0; AStderrLen := 0; AExitCode := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_run_exec(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar;
  AStdoutBuf: PAnsiChar; AStdoutBufLen: Int32;
  AStderrBuf: PAnsiChar; AStderrBufLen: Int32;
  out AResult: TPlatformProcessExecResult): Int32;
begin FillChar(AResult, SizeOf(AResult), 0); AResult.ExitCode := -1; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_create_piped(const APath: PAnsiChar; AArgv: PPAnsiChar;
  const ACwd: PAnsiChar; AOptions: TPlatformProcessOptions;
  out AProc: TPlatformProcess; out APipes: TPlatformProcessPipes): Int32;
begin FillChar(AProc, SizeOf(AProc), 0); FillChar(APipes, SizeOf(APipes), 0); Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_write_stdin_ex(AStdinWrite: PtrInt;
  AData: PAnsiChar; ALen: Int32; out ABytesWritten: Int32): Int32;
begin ABytesWritten := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_read_stdout_ex(AStdoutRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;
begin ABytesRead := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_read_stderr_ex(AStderrRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;
begin ABytesRead := 0; Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_write_stdin(AStdinWrite: PtrInt;
  AData: PAnsiChar; ALen: Int32): Int32; deprecated 'Use platform_process_write_stdin_ex';
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_read_stdout(AStdoutRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32): Int32; deprecated 'Use platform_process_read_stdout_ex';
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_process_read_stderr(AStderrRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32): Int32; deprecated 'Use platform_process_read_stderr_ex';
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_getpid: Int32;
begin Result := -1; end;
function platform_io_read(AFd: PtrInt; ABuf: Pointer; ACount: SizeUInt): PtrInt;
begin Result := -1; end;
function platform_io_write(AFd: PtrInt; ABuf: Pointer; ACount: SizeUInt): PtrInt;
begin Result := -1; end;
function platform_io_close(AFd: PtrInt): Int32;
begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_io_poll(AFds: Pointer; ACount: Int32; ATimeoutMs: Int32): Int32;
begin Result := -1; end;
{$ENDIF}

end.
