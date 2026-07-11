unit nextpas.core.process;
{**
 * @desc 进程管理门面：启动子进程、管道、超时、环境变量。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
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

implementation

uses
  nextpas.core.os.env;

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

end.
