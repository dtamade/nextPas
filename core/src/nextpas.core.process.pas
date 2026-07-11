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
 * @desc 在指定工作目录中同步执行子进程
 *
 * @params
 *   APath  可执行文件路径
 *   AArgs  命令行参数
 *   ADir   工作目录
 *}
function RunIn(const APath: string; const AArgs: array of string;
  const ADir: string): TProcessOutput;
{** @desc 执行子进程并返回 stdout 文本 *}
function Capture(const APath: string; const AArgs: array of string): string;
{**
 * @desc 在指定工作目录中执行子进程并返回 stdout 文本
 *
 * @params
 *   APath  可执行文件路径
 *   AArgs  命令行参数
 *   ADir   工作目录
 *}
function CaptureIn(const APath: string; const AArgs: array of string;
  const ADir: string): string;
{** @desc 执行子进程并返回 stdout + stderr 合并文本
 *  @note stdout 和 stderr 按进程写入顺序交错拼接，无分隔符。
 *        如需区分两个流，请使用 Run(...) 然后分别读取 .StdOut 和 .StdErr。 *}
function CaptureCombined(const APath: string;
  const AArgs: array of string): string;
{**
 * @desc 在指定工作目录中执行子进程并返回 stdout + stderr 合并文本
 *
 * @note stdout 和 stderr 按进程写入顺序交错拼接，无分隔符。
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
 *  @note stdout 和 stderr 按进程写入顺序交错拼接，无分隔符。 *}
function CaptureTimeoutCombined(const APath: string;
  const AArgs: array of string; const ATimeout: TDuration): string;
{** @desc 在指定工作目录中带超时执行并返回 stdout + stderr 合并文本
 *  @note stdout 和 stderr 按进程写入顺序交错拼接，无分隔符。 *}
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
 * @note 如果 AName 已包含目录部分，直接返回不搜索
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
 * @return 找到返回 true，未找到返回 false
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

implementation

uses
  nextpas.core.os.env,
  nextpas.core.platform.args;

function Command(const APath: string): ICommand;
begin
  Result := TCommand.New(APath);
end;

function Run(const APath: string; const AArgs: array of string): TProcessOutput;
begin
  Result := TCommand.New(APath).Args(AArgs).Output;
end;

function RunIn(const APath: string; const AArgs: array of string;
  const ADir: string): TProcessOutput;
begin
  Result := TCommand.New(APath).Args(AArgs).Dir(ADir).Output;
end;

function Capture(const APath: string; const AArgs: array of string): string;
var
  LOutput: TProcessOutput;
begin
  LOutput := Run(APath, AArgs);
  Result := LOutput.StdOut;
end;

function CaptureIn(const APath: string; const AArgs: array of string;
  const ADir: string): string;
begin
  Result := RunIn(APath, AArgs, ADir).StdOut;
end;

function CaptureCombined(const APath: string;
  const AArgs: array of string): string;
var
  LOutput: TProcessOutput;
begin
  LOutput := Run(APath, AArgs);
  Result := LOutput.StdOut + LOutput.StdErr;
end;

function CaptureInCombined(const APath: string; const AArgs: array of string;
  const ADir: string): string;
var
  LOutput: TProcessOutput;
begin
  LOutput := RunIn(APath, AArgs, ADir);
  Result := LOutput.StdOut + LOutput.StdErr;
end;

function RunTimeout(const APath: string; const AArgs: array of string;
  const ATimeout: TDuration): TProcessOutput;
begin
  Result := TCommand.New(APath).Args(AArgs).Timeout(ATimeout).Output;
end;

function CaptureTimeout(const APath: string; const AArgs: array of string;
  const ATimeout: TDuration): string;
begin
  Result := RunTimeout(APath, AArgs, ATimeout).StdOut;
end;

function RunInTimeout(const APath: string; const AArgs: array of string;
  const ADir: string; const ATimeout: TDuration): TProcessOutput;
begin
  Result := TCommand.New(APath).Args(AArgs).Dir(ADir).Timeout(ATimeout).Output;
end;

function CaptureInTimeout(const APath: string; const AArgs: array of string;
  const ADir: string; const ATimeout: TDuration): string;
begin
  Result := RunInTimeout(APath, AArgs, ADir, ATimeout).StdOut;
end;

function CaptureTimeoutCombined(const APath: string;
  const AArgs: array of string; const ATimeout: TDuration): string;
var
  LOutput: TProcessOutput;
begin
  LOutput := RunTimeout(APath, AArgs, ATimeout);
  Result := LOutput.StdOut + LOutput.StdErr;
end;

function CaptureInTimeoutCombined(const APath: string;
  const AArgs: array of string; const ADir: string;
  const ATimeout: TDuration): string;
var
  LOutput: TProcessOutput;
begin
  LOutput := RunInTimeout(APath, AArgs, ADir, ATimeout);
  Result := LOutput.StdOut + LOutput.StdErr;
end;

function RunWithInput(const APath: string; const AArgs: array of string;
  const AStdin: TBytes): TProcessOutput;
var
  LChild: IChild;
  LStdin: IWriter;
begin
  LChild := TCommand.New(APath).Args(AArgs).Stdin(stPiped)
    .Stdout(stPiped).Stderr(stPiped).Spawn;
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

function StringToBytes(const AStr: string): TBytes;
var
  LLen: Integer;
begin
  LLen := Length(AStr);
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(AStr[1], Result[0], LLen);
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
    .Stdout(stPiped).Stderr(stPiped).Spawn;
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
begin
  LEnv := EnvironmentVariables;
  LResolved := ResolveExecutablePath(AName, LEnv);
  if (LResolved = AName) and
    not CommandPathHasDirectoryPart(AName) then
    raise EProcessError.Create('executable not found in PATH: ' + AName);
  Result := LResolved;
end;

function TryLookPath(const AName: string; out APath: string): Boolean;
var
  LEnv: TStringArray;
  LResolved: string;
begin
  LEnv := EnvironmentVariables;
  LResolved := ResolveExecutablePath(AName, LEnv);
  if (LResolved = AName) and
    not CommandPathHasDirectoryPart(AName) then
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

end.
