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
  nextpas.core.process.command;

type
  TStdio = nextpas.core.process.base.TStdio;
  TProcessStatus = nextpas.core.process.base.TProcessStatus;
  TProcessOutput = nextpas.core.process.base.TProcessOutput;
  EProcessError = nextpas.core.process.base.EProcessError;
  IChild = nextpas.core.process.child.IChild;
  ICommand = nextpas.core.process.command.ICommand;

function Command(const APath: string): ICommand; inline;
function Run(const APath: string; const AArgs: array of string): TProcessOutput;
function RunIn(const APath: string; const AArgs: array of string;
  const ADir: string): TProcessOutput;
function Capture(const APath: string; const AArgs: array of string): string;

implementation

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

end.
