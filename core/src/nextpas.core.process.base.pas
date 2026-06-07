unit nextpas.core.process.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.errors,
  nextpas.core.platform.error;

type
  {**
   * TStdio
   *
   * @desc 子进程 stdio 流的配置模式
   *
   * @note 每个流（stdin/stdout/stderr）可独立配置
   *}
  TStdio = (
    stInherit,  { 继承父进程的对应 fd（默认行为） }
    stPiped,    { 创建管道，父进程可通过 IReader/IWriter 访问 }
    stNull      { 重定向到 /dev/null (Unix) 或 NUL (Windows) }
  );

  {**
   * TProcessStatus
   *
   * @desc 子进程的终止状态
   *}
  TProcessStatus = (
    psRunning,   { 进程仍在运行（TryWait 返回时） }
    psExited,    { 正常退出（ExitCode 有效） }
    psSignaled,  { 被信号终止（ExitCode = 信号号） }
    psUnknown    { 未知状态 }
  );

  {**
   * TProcessOutput
   *
   * @desc 进程执行的完整结果
   *
   * @note StdOut/StdErr 仅在对应流设为 stPiped 时有内容
   *}
  TProcessOutput = record
    ExitCode: Integer;
    Status: TProcessStatus;
    StdOut: string;
    StdErr: string;
  end;

  {**
   * EProcessError
   *
   * @desc 进程启动失败时抛出的异常
   *
   * @note ExitCode 为平台错误码（errno 或 GetLastError）
   *}
  EProcessError = class(ENextPasError)
  private
    FExitCode: Integer;
  public
    constructor Create(const AMessage: string; const AExitCode: Integer = -1);
    property ExitCode: Integer read FExitCode;
  end;

implementation

constructor EProcessError.Create(const AMessage: string; const AExitCode: Integer);
var
  LCategory: TErrorCategory;
begin
  if AExitCode = -1 then
    LCategory := ecInternal
  else
    LCategory := platform_error_category(AExitCode);
  inherited Create(AMessage, LCategory);
  FExitCode := AExitCode;
end;

end.
