unit nextpas.core.process;
{**
 * @desc 进程管理门面：启动子进程、管道、超时、环境变量。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.text.base,
  nextpas.core.time.base,
  nextpas.core.process.base,
  nextpas.core.process.child,
  nextpas.core.process.command,
  nextpas.core.process.pathresolve;

type
  TStdio = nextpas.core.process.base.TStdio;
  TProcessStatus = nextpas.core.process.base.TProcessStatus;
  TProcessOutput = nextpas.core.process.base.TProcessOutput;
  EProcessError = nextpas.core.process.base.EProcessError;
  IChild = nextpas.core.process.child.IChild;
  ICommand = nextpas.core.process.command.ICommand;

{ U1 Preferred: Command, ProcessSucceeded, LookPath, TryLookPath,
  RunChecked, MustCapture, RunTimeout, Executable.
  Compat: remaining Run*/Capture* combinations (kept; use builder for new code). }

{** cProcessDefaultMaxOutput — free-function Capture/Run* buffer cap (64 MiB).
 *  ICommand.MaxOutput default remains 0 (unlimited). Same value as process.base. *}
const
  cProcessDefaultMaxOutput: Int64 = 64 * 1024 * 1024;

{**
 * @desc 判断进程结果是否成功
 *
 * @return 非 TimedOut、非 OutputLimited、非 Cancelled 且 Status=psExited 且 ExitCode=0 时为 True
 *
 * @note 对标 Go ProcessState.Success / Rust ExitStatus::success
 *}
function ProcessSucceeded(const AOut: TProcessOutput): Boolean; inline;

{**
 * @desc 创建命令构建器，通过链式调用配置子进程参数
 *
 * @params
 *   APath  可执行文件路径
 *}
function Command(const APath: string): ICommand; inline;
{**
 * @desc 同步执行子进程并等待完成，返回输出
 *
 * @params
 *   APath  可执行文件路径
 *   AArgs  命令行参数
 *}
function Run(const APath: string; const AArgs: array of string): TProcessOutput;
{**
 * @desc 以单条参数字符串执行外部程序并返回退出码
 *       (SysUtils.ExecuteProcess 兼容;参数按空白拆分,双引号分组视为
 *        一个参数,引号本身不进入参数值)
 *
 * @params
 *   APath    可执行文件路径
 *   AParams  空格分隔的命令行参数(可含 "..." 分组)
 *
 * @return 子进程退出码(启动失败返回平台错误码;详情看 TProcessOutput)
 *}
function ExecuteProcess(const APath, AParams: string): Integer;
{**
 * @desc 在指定工作目录中同步执行子进程
 *
 * @params
 *   APath  可执行文件路径
 *   AArgs  命令行参数
 *   ADir   工作目录
 *}
function RunIn(const APath: string; const AArgs: array of string;
  const ADir: string): TProcessOutput;
{** @desc 同步执行并在非成功退出时抛 EProcessError（exit≠0 / 信号 / 超时） *}
function RunChecked(const APath: string; const AArgs: array of string): TProcessOutput;
{** @desc 在指定目录同步执行并在非成功退出时抛 EProcessError *}
function RunInChecked(const APath: string; const AArgs: array of string;
  const ADir: string): TProcessOutput;
{** @desc 执行子进程并返回 stdout 文本。
 *  @note 不检查退出码；失败时仍可能返回部分 stdout。需要失败即错请用 MustCapture。 *}
function Capture(const APath: string; const AArgs: array of string): string;
{**
 * @desc 在指定工作目录中执行子进程并返回 stdout 文本
 *
 * @note 不检查退出码；需要失败即错请用 MustCaptureIn。
 *
 * @params
 *   APath  可执行文件路径
 *   AArgs  命令行参数
 *   ADir   工作目录
 *}
function CaptureIn(const APath: string; const AArgs: array of string;
  const ADir: string): string;
{** @desc 执行并返回 stdout；非成功退出抛 EProcessError（消息含 stderr 摘要） *}
function MustCapture(const APath: string; const AArgs: array of string): string;
{** @desc 在指定目录执行并返回 stdout；非成功退出抛 EProcessError *}
function MustCaptureIn(const APath: string; const AArgs: array of string;
  const ADir: string): string;
{** @desc 执行子进程并返回 stdout + stderr 合并文本
 *  @note 子进程 stderr 重定向到 stdout 管道，按写入时间交错（对齐 Go CombinedOutput）。
 *        不检查退出码；需要失败即错请用 MustCaptureCombined。
 *        如需区分两个流，请使用 Run(...) 然后分别读取 .StdOut 和 .StdErr。 *}
function CaptureCombined(const APath: string;
  const AArgs: array of string): string;
{** @desc 执行并返回 stdout+stderr 合并文本；非成功退出抛 EProcessError *}
function MustCaptureCombined(const APath: string;
  const AArgs: array of string): string;
{**
 * @desc 在指定工作目录中执行子进程并返回 stdout + stderr 合并文本
 *
 * @note stderr 重定向到 stdout 管道，按写入时间交错。
 *       不检查退出码。
 *
 * @params
 *   APath  可执行文件路径
 *   AArgs  命令行参数
 *   ADir   工作目录
 *}
function CaptureInCombined(const APath: string; const AArgs: array of string;
  const ADir: string): string;
{**
 * @desc 执行子进程，通过 stdin 传入数据，返回输出
 *
 * @params
 *   APath    可执行文件路径
 *   AArgs    命令行参数
 *   AStdin   传入 stdin 的数据
 *}
function RunWithInput(const APath: string; const AArgs: array of string;
  const AStdin: TBytes): TProcessOutput;
{**
 * @desc 执行子进程，通过 stdin 传入数据，返回 stdout 文本
 *
 * @params
 *   APath    可执行文件路径
 *   AArgs    命令行参数
 *   AStdin   传入 stdin 的数据
 *}
function CaptureWithInput(const APath: string; const AArgs: array of string;
  const AStdin: TBytes): string;
{**
 * @desc 执行子进程，通过 stdin 传入字符串，返回输出
 *
 * @params
 *   APath    可执行文件路径
 *   AArgs    命令行参数
 *   AStdin   传入 stdin 的字符串
 *}
function RunWithInputString(const APath: string; const AArgs: array of string;
  const AStdin: string): TProcessOutput;
{**
 * @desc 执行子进程，通过 stdin 传入字符串，返回 stdout 文本
 *
 * @params
 *   APath    可执行文件路径
 *   AArgs    命令行参数
 *   AStdin   传入 stdin 的字符串
 *}
function CaptureWithInputString(const APath: string; const AArgs: array of string;
  const AStdin: string): string;
{**
 * @desc 在指定工作目录中执行子进程，通过 stdin 传入数据，返回 stdout 文本
 *
 * @params
 *   APath    可执行文件路径
 *   AArgs    命令行参数
 *   ADir     工作目录
 *   AStdin   传入 stdin 的数据
 *}
function CaptureInWithInput(const APath: string; const AArgs: array of string;
  const ADir: string; const AStdin: TBytes): string;
{**
 * @desc 在指定工作目录中执行子进程，通过 stdin 传入字符串，返回 stdout 文本
 *
 * @params
 *   APath    可执行文件路径
 *   AArgs    命令行参数
 *   ADir     工作目录
 *   AStdin   传入 stdin 的字符串
 *}
function CaptureInWithInputString(const APath: string; const AArgs: array of string;
  const ADir: string; const AStdin: string): string;
{**
 * @desc 在指定工作目录中执行子进程，通过 stdin 传入数据，返回输出
 *
 * @params
 *   APath    可执行文件路径
 *   AArgs    命令行参数
 *   ADir     工作目录
 *   AStdin   传入 stdin 的数据
 *}
function RunInWithInput(const APath: string; const AArgs: array of string;
  const ADir: string; const AStdin: TBytes): TProcessOutput;
{**
 * @desc 在指定工作目录中执行子进程，通过 stdin 传入字符串，返回输出
 *
 * @params
 *   APath    可执行文件路径
 *   AArgs    命令行参数
 *   ADir     工作目录
 *   AStdin   传入 stdin 的字符串
 *}
function RunInWithInputString(const APath: string; const AArgs: array of string;
  const ADir: string; const AStdin: string): TProcessOutput;
{**
 * @desc 带超时的同步执行，超时后自动 Kill
 *
 * @params
 *   APath     可执行文件路径
 *   AArgs     命令行参数
 *   ATimeout  超时时间
 *}
function RunTimeout(const APath: string; const AArgs: array of string;
  const ATimeout: TDuration): TProcessOutput;
{**
 * @desc 带超时的执行并返回 stdout 文本
 *
 * @params
 *   APath     可执行文件路径
 *   AArgs     命令行参数
 *   ATimeout  超时时间
 *}
function CaptureTimeout(const APath: string; const AArgs: array of string;
  const ATimeout: TDuration): string;
{**
 * @desc 在指定工作目录中带超时执行，超时后自动 Kill
 *
 * @params
 *   APath     可执行文件路径
 *   AArgs     命令行参数
 *   ADir      工作目录
 *   ATimeout  超时时间
 *}
function RunInTimeout(const APath: string; const AArgs: array of string;
  const ADir: string; const ATimeout: TDuration): TProcessOutput;
{**
 * @desc 在指定工作目录中带超时执行并返回 stdout 文本
 *
 * @params
 *   APath     可执行文件路径
 *   AArgs     命令行参数
 *   ADir      工作目录
 *   ATimeout  超时时间
 *}
function CaptureInTimeout(const APath: string; const AArgs: array of string;
  const ADir: string; const ATimeout: TDuration): string;
{** @desc 带超时执行并返回 stdout + stderr 合并文本
 *  @note stderr 重定向到 stdout 管道，按写入时间交错。 *}
function CaptureTimeoutCombined(const APath: string;
  const AArgs: array of string; const ATimeout: TDuration): string;
{** @desc 在指定工作目录中带超时执行并返回 stdout + stderr 合并文本
 *  @note stderr 重定向到 stdout 管道，按写入时间交错。 *}
function CaptureInTimeoutCombined(const APath: string;
  const AArgs: array of string; const ADir: string;
  const ATimeout: TDuration): string;
{**
 * @desc 在 PATH 中搜索可执行文件（类似 Go 的 exec.LookPath）
 *
 * @params
 *   AName  可执行文件名（如 'fpc'）或绝对/相对路径
 *
 * @return 找到的完整路径；未找到时抛出 EProcessError
 *
 * @note 若 AName 含目录部分，校验该路径可执行后返回；不可执行则抛错
 * @note 使用当前进程的 PATH 环境变量
 *}
function LookPath(const AName: string): string;
{**
 * @desc 尝试在 PATH 中搜索可执行文件（不抛异常版本）
 *
 * @params
 *   AName   可执行文件名或路径
 *   APath   输出找到的完整路径
 *
 * @return 找到且可执行返回 true，否则 false（APath 为空）
 *}
function TryLookPath(const AName: string; out APath: string): Boolean;
{** @desc 获取当前进程的可执行文件完整路径
 *
 * @return 可执行文件的绝对路径
 *
 * @note Linux 使用 /proc/self/exe
 * @note 其他平台回退到 ParamStr(0)
 * @note 路径可能不存在（如被移动/删除）
 *}
function Executable: string;

{**
 * @desc 获取当前进程 PID
 *
 * @return 当前进程的 OS PID
 *
 * @note 对照 Go os.Getpid / Rust std::process::id
 *}
function CurrentPid: Int32;

{**
 * @desc 检查指定 PID 的进程是否存活
 *
 * @params
 *   APid  目标进程 PID
 *
 * @return 进程存活返回 True；进程不存在或权限不足返回 False
 *
 * @note Unix 用 kill(pid, 0)（信号 0 不杀进程，仅探活）
 * @note 对照 grok is_process_alive / Rust std::process::Child::try_wait
 * @note PID <= 0 一律返回 False（非法 PID）
 *}
function IsProcessAlive(APid: Int32): Boolean;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.os.env,
  nextpas.core.platform.args,
  nextpas.core.platform.process,
  nextpas.core.text.conv;

function ProcessSucceeded(const AOut: TProcessOutput): Boolean;
begin
  Result := (not AOut.TimedOut) and (not AOut.OutputLimited) and
    (not AOut.Cancelled) and
    (AOut.Status = psExited) and (AOut.ExitCode = 0);
end;

function Command(const APath: string): ICommand;
begin
  Result := TCommand.New(APath);
end;

procedure RaiseIfProcessFailed(const APath: string; const AOut: TProcessOutput);
var
  LMsg, LDetail: string;
  LEx: EProcessError;
begin
  if ProcessSucceeded(AOut) then
    Exit;
  if AOut.OutputLimited then
    LMsg := 'process output exceeded MaxOutput: ' + APath
  else if AOut.Cancelled then
    LMsg := 'process cancelled: ' + APath
  else if AOut.TimedOut then
    LMsg := 'process timed out: ' + APath
  else if AOut.Status = psSignaled then
    LMsg := 'process killed by signal ' + IntToStr(AOut.ExitCode) + ': ' + APath
  else
    LMsg := 'process exited with code ' + IntToStr(AOut.ExitCode) + ': ' + APath;
  LDetail := AOut.StdErr;
  if LDetail = '' then
    LDetail := AOut.StdOut;
  if Length(LDetail) > 200 then
    LDetail := Copy(LDetail, 1, 200) + '...';
  if LDetail <> '' then
    LMsg := LMsg + ' — ' + LDetail;
  LEx := EProcessError.Create(LMsg, AOut.ExitCode, AOut.TimedOut, AOut.OutputLimited,
    AOut.Cancelled);
  raise LEx;
end;

function Run(const APath: string; const AArgs: array of string): TProcessOutput;
begin
  Result := TCommand.New(APath).Args(AArgs)
    .MaxOutput(cProcessDefaultMaxOutput).Output;
end;

{ 空白拆分 + 双引号分组(SysUtils.ExecuteProcess 参数串语义);引号不进参数值 }
function SplitCommandLine(const S: string): TStringArray;
var
  I, J, Start, N: Integer;
  InQ: Boolean;
begin
  Result := nil;
  SetLength(Result, 0);
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    while (I <= Length(S)) and (S[I] in [' ', #9]) do
      Inc(I);
    if I > Length(S) then
      Break;
    Start := I;
    InQ := False;
    while I <= Length(S) do
    begin
      if S[I] = '"' then
        InQ := not InQ
      else if (not InQ) and (S[I] in [' ', #9]) then
        Break;
      Inc(I);
    end;
    Inc(N);
    SetLength(Result, N);
    Result[N - 1] := '';
    for J := Start to I - 1 do
      if S[J] <> '"' then
        Result[N - 1] := Result[N - 1] + S[J];
  end;
end;

function ExecuteProcess(const APath, AParams: string): Integer;
var
  LOut: TProcessOutput;
begin
  LOut := TCommand.New(APath).Args(SplitCommandLine(AParams))
    .MaxOutput(cProcessDefaultMaxOutput).Output;
  Result := LOut.ExitCode;
end;

function RunIn(const APath: string; const AArgs: array of string;
  const ADir: string): TProcessOutput;
begin
  Result := TCommand.New(APath).Args(AArgs).Dir(ADir)
    .MaxOutput(cProcessDefaultMaxOutput).Output;
end;

function RunChecked(const APath: string; const AArgs: array of string): TProcessOutput;
begin
  Result := Run(APath, AArgs);
  RaiseIfProcessFailed(APath, Result);
end;

function RunInChecked(const APath: string; const AArgs: array of string;
  const ADir: string): TProcessOutput;
begin
  Result := RunIn(APath, AArgs, ADir);
  RaiseIfProcessFailed(APath, Result);
end;

function Capture(const APath: string; const AArgs: array of string): string;
var
  LChild: IChild;
begin
  { stdout only — stderr to null. Avoid dual-pipe WaitWithOutput cost for short Capture. }
  LChild := TCommand.New(APath).Args(AArgs)
    .MaxOutput(cProcessDefaultMaxOutput)
    .Stdout(stPiped).Stderr(stNull).Spawn;
  Result := LChild.WaitWithOutput.StdOut;
end;

function CaptureIn(const APath: string; const AArgs: array of string;
  const ADir: string): string;
var
  LChild: IChild;
begin
  LChild := TCommand.New(APath).Args(AArgs).Dir(ADir)
    .MaxOutput(cProcessDefaultMaxOutput)
    .Stdout(stPiped).Stderr(stNull).Spawn;
  Result := LChild.WaitWithOutput.StdOut;
end;

function MustCapture(const APath: string; const AArgs: array of string): string;
var
  LChild: IChild;
  LOutput: TProcessOutput;
begin
  LChild := TCommand.New(APath).Args(AArgs)
    .MaxOutput(cProcessDefaultMaxOutput)
    .Stdout(stPiped).Stderr(stNull).Spawn;
  LOutput := LChild.WaitWithOutput;
  RaiseIfProcessFailed(APath, LOutput);
  Result := LOutput.StdOut;
end;

function MustCaptureIn(const APath: string; const AArgs: array of string;
  const ADir: string): string;
var
  LChild: IChild;
  LOutput: TProcessOutput;
begin
  LChild := TCommand.New(APath).Args(AArgs).Dir(ADir)
    .MaxOutput(cProcessDefaultMaxOutput)
    .Stdout(stPiped).Stderr(stNull).Spawn;
  LOutput := LChild.WaitWithOutput;
  RaiseIfProcessFailed(APath, LOutput);
  Result := LOutput.StdOut;
end;

function CaptureCombined(const APath: string;
  const AArgs: array of string): string;
begin
  Result := TCommand.New(APath).Args(AArgs).MergeStderr
    .MaxOutput(cProcessDefaultMaxOutput).Output.StdOut;
end;

function MustCaptureCombined(const APath: string;
  const AArgs: array of string): string;
var
  LOutput: TProcessOutput;
begin
  LOutput := TCommand.New(APath).Args(AArgs).MergeStderr
    .MaxOutput(cProcessDefaultMaxOutput).Output;
  RaiseIfProcessFailed(APath, LOutput);
  Result := LOutput.StdOut;
end;

function CaptureInCombined(const APath: string; const AArgs: array of string;
  const ADir: string): string;
begin
  Result := TCommand.New(APath).Args(AArgs).Dir(ADir).MergeStderr
    .MaxOutput(cProcessDefaultMaxOutput).Output.StdOut;
end;

function RunTimeout(const APath: string; const AArgs: array of string;
  const ATimeout: TDuration): TProcessOutput;
begin
  Result := TCommand.New(APath).Args(AArgs).Timeout(ATimeout)
    .MaxOutput(cProcessDefaultMaxOutput).Output;
end;

function CaptureTimeout(const APath: string; const AArgs: array of string;
  const ATimeout: TDuration): string;
begin
  Result := RunTimeout(APath, AArgs, ATimeout).StdOut;
end;

function RunInTimeout(const APath: string; const AArgs: array of string;
  const ADir: string; const ATimeout: TDuration): TProcessOutput;
begin
  Result := TCommand.New(APath).Args(AArgs).Dir(ADir).Timeout(ATimeout)
    .MaxOutput(cProcessDefaultMaxOutput).Output;
end;

function CaptureInTimeout(const APath: string; const AArgs: array of string;
  const ADir: string; const ATimeout: TDuration): string;
begin
  Result := RunInTimeout(APath, AArgs, ADir, ATimeout).StdOut;
end;

function CaptureTimeoutCombined(const APath: string;
  const AArgs: array of string; const ATimeout: TDuration): string;
begin
  Result := TCommand.New(APath).Args(AArgs).Timeout(ATimeout).MergeStderr
    .MaxOutput(cProcessDefaultMaxOutput).Output.StdOut;
end;

function CaptureInTimeoutCombined(const APath: string;
  const AArgs: array of string; const ADir: string;
  const ATimeout: TDuration): string;
begin
  Result := TCommand.New(APath).Args(AArgs).Dir(ADir).Timeout(ATimeout)
    .MergeStderr.MaxOutput(cProcessDefaultMaxOutput).Output.StdOut;
end;

function RunWithInput(const APath: string; const AArgs: array of string;
  const AStdin: TBytes): TProcessOutput;
var
  LChild: IChild;
  LStdin: IWriter;
begin
  LChild := TCommand.New(APath).Args(AArgs).Stdin(stPiped)
    .Stdout(stPiped).Stderr(stPiped)
    .MaxOutput(cProcessDefaultMaxOutput).Spawn;
  LStdin := LChild.TakeStdin;
  if (LStdin <> nil) and (Length(AStdin) > 0) then
    LStdin.Write(AStdin[0], Length(AStdin));
  LStdin := nil;
  Result := LChild.WaitWithOutput;
end;

function CaptureWithInput(const APath: string; const AArgs: array of string;
  const AStdin: TBytes): string;
begin
  Result := RunWithInput(APath, AArgs, AStdin).StdOut;
end;

function RunWithInputString(const APath: string; const AArgs: array of string;
  const AStdin: string): TProcessOutput;
begin
  Result := RunWithInput(APath, AArgs, StringToBytes(AStdin));
end;

function CaptureWithInputString(const APath: string; const AArgs: array of string;
  const AStdin: string): string;
begin
  Result := RunWithInputString(APath, AArgs, AStdin).StdOut;
end;

function CaptureInWithInput(const APath: string; const AArgs: array of string;
  const ADir: string; const AStdin: TBytes): string;
begin
  Result := RunInWithInput(APath, AArgs, ADir, AStdin).StdOut;
end;

function CaptureInWithInputString(const APath: string; const AArgs: array of string;
  const ADir: string; const AStdin: string): string;
begin
  Result := RunInWithInputString(APath, AArgs, ADir, AStdin).StdOut;
end;

function RunInWithInput(const APath: string; const AArgs: array of string;
  const ADir: string; const AStdin: TBytes): TProcessOutput;
var
  LChild: IChild;
  LStdin: IWriter;
begin
  LChild := TCommand.New(APath).Args(AArgs).Dir(ADir).Stdin(stPiped)
    .Stdout(stPiped).Stderr(stPiped)
    .MaxOutput(cProcessDefaultMaxOutput).Spawn;
  LStdin := LChild.TakeStdin;
  if (LStdin <> nil) and (Length(AStdin) > 0) then
    LStdin.Write(AStdin[0], Length(AStdin));
  LStdin := nil;
  Result := LChild.WaitWithOutput;
end;

function RunInWithInputString(const APath: string; const AArgs: array of string;
  const ADir: string; const AStdin: string): TProcessOutput;
begin
  Result := RunInWithInput(APath, AArgs, ADir, StringToBytes(AStdin));
end;

function LookPath(const AName: string): string;
var
  LEnv: TStringArray;
  LResolved: string;
  LPath: string;
begin
  LEnv := EnvironmentVariables;
  LResolved := ResolveExecutablePath(AName, LEnv);
  if LResolved = '' then
  begin
    if CommandPathHasDirectoryPart(AName) then
      raise EProcessError.Create('executable not found: ' + AName)
    else
    begin
      LPath := GetEnv('PATH');
      if Length(LPath) > 200 then
        LPath := Copy(LPath, 1, 200) + '...';
      raise EProcessError.Create('executable not found in PATH: ' + AName +
        ' (searched: ' + LPath + ')');
    end;
  end;
  Result := LResolved;
end;

function TryLookPath(const AName: string; out APath: string): Boolean;
var
  LEnv: TStringArray;
  LResolved: string;
begin
  LEnv := EnvironmentVariables;
  LResolved := ResolveExecutablePath(AName, LEnv);
  if LResolved = '' then
  begin
    APath := '';
    Result := False;
  end
  else
  begin
    APath := LResolved;
    Result := True;
  end;
end;

function Executable: string;
var
  LBuf: array[0..4095] of AnsiChar;
  LLen: Int32;
begin
  LLen := platform_args_exe_path(@LBuf[0], SizeOf(LBuf));
  if LLen < 0 then
    raise EProcessError.Create('Failed to get executable path (code=' + IntToStr(LLen) + ')');
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(LBuf[0], Result[1], LLen);
end;

function CurrentPid: Int32;
begin
  Result := platform_getpid;
end;

function IsProcessAlive(APid: Int32): Boolean;
var
  Ret: Int32;
begin
  if APid <= 0 then
    Exit(False);
  { kill(pid, 0)：信号 0 不杀进程，仅检查存活/权限
    返回 0 = 存活；errno=ESRCH(3) = 不存在；errno=EPERM(1) = 存在但无权限 }
  Ret := platform_process_signal_pid(APid, 0);
  Result := (Ret = 0);
end;

end.
