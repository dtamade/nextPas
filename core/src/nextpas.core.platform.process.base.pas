unit nextpas.core.platform.process.base;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc 进程句柄（平台无关封装） *}
  TPlatformProcess = record
  {$IFDEF NEXTPAS_WINDOWS}
    ProcessHandle: PtrUInt;
    ThreadHandle: PtrUInt;
    Pid: UInt32;
  {$ELSE}
    Pid: Int32;
  {$ENDIF}
    {** @desc 检查进程句柄是否有效
        @return True 如果进程句柄有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查进程句柄是否无效
        @return True 如果进程句柄无效 *}
    function IsInvalid: Boolean; inline;
  end;

  {** @desc 进程退出状态枚举 *}
  TPlatformProcessStatus = (
    psRunning,
    psExited,
    psSignaled,
    psUnknown
  );

  {** @desc 进程运行结果
      ExitCode 语义：
      - 正常退出时为程序返回码（POSIX 通常是 0..125，Windows 为进程原始退出码）
      - POSIX 被信号终止时编码为 128 + signal，遵循常见 shell 约定 *}
  TPlatformProcessResult = record
    Status: TPlatformProcessStatus;
    ExitCode: Int32;
    {** @desc 检查进程是否正在运行
        @return True 如果进程正在运行 *}
    function IsRunning: Boolean; inline;
    {** @desc 检查进程是否已退出
        @return True 如果进程已退出 *}
    function IsExited: Boolean; inline;
    {** @desc 检查进程是否被信号终止
        @return True 如果进程被信号终止 *}
    function IsSignaled: Boolean; inline;
    {** @desc 检查进程是否成功退出（退出码为 0）
        @return True 如果进程成功退出 *}
    function IsSuccess: Boolean; inline;
  end;

  {** @desc 进程管道集合（stdin/stdout/stderr） *}
  TPlatformProcessPipes = record
    StdinWrite: PtrInt;
    StdoutRead: PtrInt;
    StderrRead: PtrInt;
    {** @desc 检查所有管道是否有效
        @return True 如果所有管道有效 *}
    function IsValid: Boolean; inline;
    {** @desc 检查是否有任何无效管道
        @return True 如果有任何无效管道 *}
    function HasInvalid: Boolean; inline;
  end;

  {** @desc 进程启动失败阶段枚举 *}
  TPlatformProcessSpawnStage = (
    pssNone,
    pssPipe,
    pssFork,
    pssChdir,
    pssDupStdin,
    pssDupStdout,
    pssDupStderr,
    pssExec
  );

  {** @desc POSIX spawn 错误传输结构（通过管道传递） *}
  TPosixSpawnWireError = packed record
    Stage: UInt8;
    Reserved: array[0..2] of UInt8;
    ErrNo: Int32;
  end;

  {** @desc 进程创建选项 *}
  TPlatformProcessOption = (
    poCaptureStdout,   {**< 捕获 stdout 输出 *}
    poCaptureStderr,   {**< 捕获 stderr 输出 *}
    poRedirectStdin    {**< 重定向 stdin *}
  );
  TPlatformProcessOptions = set of TPlatformProcessOption;

  {** @desc 进程执行结果（便利结构） *}
  TPlatformProcessExecResult = record
    ExitCode: Int32;
    Stdout: PAnsiChar;
    StdoutLen: Int32;
    Stderr: PAnsiChar;
    StderrLen: Int32;
    {** @desc 检查进程是否成功退出
        @return True 如果退出码为 0 *}
    function IsSuccess: Boolean; inline;
  end;

implementation

function TPlatformProcess.IsValid: Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := ProcessHandle <> 0;
{$ELSE}
  Result := Pid > 0;
{$ENDIF}
end;

function TPlatformProcess.IsInvalid: Boolean;
begin
{$IFDEF NEXTPAS_WINDOWS}
  Result := ProcessHandle = 0;
{$ELSE}
  Result := Pid <= 0;
{$ENDIF}
end;

function TPlatformProcessResult.IsRunning: Boolean;
begin
  Result := Status = psRunning;
end;

function TPlatformProcessResult.IsExited: Boolean;
begin
  Result := Status = psExited;
end;

function TPlatformProcessResult.IsSignaled: Boolean;
begin
  Result := Status = psSignaled;
end;

function TPlatformProcessResult.IsSuccess: Boolean;
begin
  Result := (Status = psExited) and (ExitCode = 0);
end;

function TPlatformProcessPipes.IsValid: Boolean;
begin
  Result := (StdinWrite >= 0) and (StdoutRead >= 0) and (StderrRead >= 0);
end;

function TPlatformProcessPipes.HasInvalid: Boolean;
begin
  Result := (StdinWrite < 0) or (StdoutRead < 0) or (StderrRead < 0);
end;

function TPlatformProcessExecResult.IsSuccess: Boolean;
begin
  Result := ExitCode = 0;
end;

end.
