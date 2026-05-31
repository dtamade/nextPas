unit nextpas.core.process.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.errors;

type
  { Stdio 配置：子进程的 stdin/stdout/stderr 如何处理 }
  TStdio = (
    stInherit,  // 继承父进程（默认）
    stPiped,    // 创建管道，可通过 IReader/IWriter 访问
    stNull      // 重定向到 /dev/null (Unix) 或 NUL (Windows)
  );

  { 进程状态 }
  TProcessStatus = (
    psRunning,
    psExited,
    psSignaled,
    psUnknown
  );

  { 进程执行结果 }
  TProcessOutput = record
    ExitCode: Integer;
    Status: TProcessStatus;
    StdOut: string;
    StdErr: string;
  end;

  { EProcessError — 进程执行失败异常 }
  EProcessError = class(Exception)
  private
    FExitCode: Integer;
  public
    constructor Create(const AMessage: string; const AExitCode: Integer = -1);
    property ExitCode: Integer read FExitCode;
  end;

implementation

constructor EProcessError.Create(const AMessage: string; const AExitCode: Integer);
begin
  inherited Create(AMessage);
  FExitCode := AExitCode;
end;

end.
