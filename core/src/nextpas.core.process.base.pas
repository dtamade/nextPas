unit nextpas.core.process.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.base,
  nextpas.core.errors;

const
  {** U1: free-function Capture/Run* that buffer stdout/stderr apply this MaxOutput.
   *  ICommand.MaxOutput default remains 0 (unlimited). Use .MaxOutput(0) for unlimited via builder. *}
  cProcessDefaultMaxOutput: Int64 = 64 * 1024 * 1024;

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
   * @note Status（ICommand.Status）不捕获输出：StdOut/StdErr 恒空
   * @note TimedOut=True 表示因 ICommand.Timeout 到期而被 Kill；
   *       此时 Status 通常为 psSignaled，ExitCode 为信号相关值
   * @note OutputLimited=True 表示 stdout+stderr 累计超过 ICommand.MaxOutput；
   *       与 TimedOut 独立，不伪装为超时
   * @note Cancelled=True 表示 CancelToken 触发 Kill（与 TimedOut 独立）
   *}
  TProcessOutput = record
    ExitCode: Integer;
    Status: TProcessStatus;
    StdOut: string;
    StdErr: string;
    TimedOut: Boolean;
    OutputLimited: Boolean;
    {** True 表示 CancelToken 触发 Kill（与 TimedOut 独立） *}
    Cancelled: Boolean;
  end;

  {**
   * EProcessError
   *
   * @desc 进程启动失败或非成功退出时抛出的异常
   *
   * @note ExitCode 为退出码 / 信号 / 平台错误码（视场景）
   * @note TimedOut / OutputLimited / Cancelled 便于结构化判断，无需解析 Message
   *}
  EProcessError = class(Exception)
  private
    FExitCode: Integer;
    FTimedOut: Boolean;
    FOutputLimited: Boolean;
    FCancelled: Boolean;
  public
    constructor Create(const AMessage: string; const AExitCode: Integer = -1;
      const ATimedOut: Boolean = False; const AOutputLimited: Boolean = False;
      const ACancelled: Boolean = False);
    property ExitCode: Integer read FExitCode;
    property TimedOut: Boolean read FTimedOut;
    property OutputLimited: Boolean read FOutputLimited;
    property Cancelled: Boolean read FCancelled;
  end;

implementation

constructor EProcessError.Create(const AMessage: string; const AExitCode: Integer;
  const ATimedOut: Boolean; const AOutputLimited: Boolean;
  const ACancelled: Boolean);
begin
  inherited Create(AMessage);
  FExitCode := AExitCode;
  FTimedOut := ATimedOut;
  FOutputLimited := AOutputLimited;
  FCancelled := ACancelled;
end;

end.
