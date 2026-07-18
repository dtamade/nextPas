unit nextpas.core.process.child;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.process.base,
  nextpas.core.platform.process.base;

type
  {**
   * IChild
   *
   * @desc 正在运行的子进程句柄
   *
   * @note 释放时自动 Kill + Wait（防止僵尸进程）
   * @note 如果 stdout/stderr 是 Piped，必须在 Wait 之前读完（否则可能死锁）
   *       推荐用 WaitWithOutput 自动处理
   *}
  {** @note 非线程安全。IChild 的所有方法必须在同一线程调用 *}
  IChild = interface
    ['{A1B2C3D4-E5F6-7890-AB01-000000000001}']
    {** 阻塞等待子进程退出，返回退出状态 *}
    function Wait: TProcessOutput;
    {** 非阻塞检查子进程是否已退出。返回 False 表示仍在运行 *}
    function TryWait(out AOutput: TProcessOutput): Boolean;
    {** 放弃对子进程生命周期的管理，让子进程在句柄释放后继续运行。
     *    适用于 launcher 这类父进程即将退出的场景，不提供长期 daemon reaping 语义。 *}
    procedure Detach;
    {** 发送 SIGKILL 终止子进程 *}
    procedure Kill;
    {** 发送指定信号给子进程
     *    @param ASignal  信号号（如 SIGTERM=15, SIGINT=2）
     *    @note 常用信号：SIGTERM(15)=优雅终止, SIGINT(2)=中断, SIGKILL(9)=强制终止 *}
    procedure Signal(ASignal: Integer);
    {** 子进程 PID *}
    function Pid: Integer;
    {** 取走 stdin 写入器（调用后 IChild 不再持有）*}
    function TakeStdin: IWriter;
    {** 取走 stdout 读取器 *}
    function TakeStdout: IReader;
    {** 取走 stderr 读取器 *}
    function TakeStderr: IReader;
    {** 关闭 stdin，并发读取 stdout+stderr，然后 Wait。推荐用法 *}
    function WaitWithOutput: TProcessOutput;
  end;

  { TChild — IChild 实现 }
  TChild = class(TInterfacedObject, IChild)
  private
    FProc: TPlatformProcess;
    FStdinWriter: IWriter;
    FStdoutReader: IReader;
    FStderrReader: IReader;
    FWaited: Boolean;
    FDetached: Boolean;
    FTimeout: TDuration;
    FMaxOutput: Int64;
    FLastOutput: TProcessOutput;
    procedure EnsureAttached;
    procedure RaiseProcessPlatformError(const AOp: string; ACode: Int32);
    function FinishWaitResult(const AResult: TPlatformProcessResult;
      const AStdOut, AStdErr: string;
      const ATimedOut: Boolean = False;
      const AOutputLimited: Boolean = False): TProcessOutput;
  public
    constructor Create(const AProc: TPlatformProcess;
      const AStdin: IWriter; const AStdout: IReader; const AStderr: IReader;
      const ATimeout: TDuration; const AMaxOutput: Int64 = 0);
    destructor Destroy; override;
    function Wait: TProcessOutput;
    function TryWait(out AOutput: TProcessOutput): Boolean;
    procedure Detach;
    procedure Kill;
    procedure Signal(ASignal: Integer);
    function Pid: Integer;
    function TakeStdin: IWriter;
    function TakeStdout: IReader;
    function TakeStderr: IReader;
    function WaitWithOutput: TProcessOutput;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.platform.error,
  nextpas.core.platform.process,
  nextpas.core.platform.thread,
  nextpas.core.process.pipe,
  nextpas.core.text.conv;

procedure CloseWriterBestEffort(var AWriter: IWriter);
var
  LCloser: IWriteCloser;
begin
  if AWriter = nil then
    Exit;
  try
    if nextpas.core.base.utils.Supports(AWriter, IWriteCloser, LCloser) then
      LCloser.Close;
  finally
    AWriter := nil;
  end;
end;

{ TChild }

constructor TChild.Create(const AProc: TPlatformProcess;
  const AStdin: IWriter; const AStdout: IReader; const AStderr: IReader;
  const ATimeout: TDuration; const AMaxOutput: Int64);
begin
  inherited Create;
  FProc := AProc;
  FStdinWriter := AStdin;
  FStdoutReader := AStdout;
  FStderrReader := AStderr;
  FWaited := False;
  FDetached := False;
  FTimeout := ATimeout;
  FMaxOutput := AMaxOutput;
  FillChar(FLastOutput, SizeOf(FLastOutput), 0);
end;

procedure TChild.EnsureAttached;
begin
  if FDetached then
    raise EProcessError.Create('process child is detached');
end;

procedure TChild.RaiseProcessPlatformError(const AOp: string; ACode: Int32);
var
  LBuf: array[0..255] of AnsiChar;
  LMsg: string;
begin
  LMsg := AOp + ' failed (' + IntToStr(ACode) + ')';
  if platform_error_message(ACode, @LBuf[0], SizeOf(LBuf)) > 0 then
    LMsg := LMsg + ': ' + string(PAnsiChar(@LBuf[0]));
  raise EProcessError.Create(LMsg, ACode);
end;

destructor TChild.Destroy;
const
  DESTROY_TIMEOUT_NS = 5000000000; { 5 seconds }
var
  LResult: TPlatformProcessResult;
  LDeadline: TInstant;
begin
  if (not FWaited) and (not FDetached) then
  begin
    if platform_process_try_wait(FProc, LResult) = 0 then
      if LResult.Status = nextpas.core.platform.process.base.psRunning then
      begin
        if platform_process_kill(FProc) = 0 then
        begin
          LDeadline := TInstant.Now.Add(TDuration.FromNanoseconds(DESTROY_TIMEOUT_NS));
          repeat
            if platform_process_try_wait(FProc, LResult) <> 0 then
              Break;
            if LResult.Status <> nextpas.core.platform.process.base.psRunning then
              Break;
            if TInstant.Now.DurationSince(LDeadline).IsPositive then
            begin
              { Timeout: abandon child to avoid blocking destructor }
              Break;
            end;
            platform_thread_sleep_ns(10000000);
          until False;
        end
        else
          platform_process_try_wait(FProc, LResult);
      end;
  end;
  if not FDetached then
    platform_process_detach(FProc);
  try
    CloseWriterBestEffort(FStdinWriter);
  except
    { destructor cleanup is best effort }
  end;
  FStdoutReader := nil;
  FStderrReader := nil;
  inherited;
end;

function TChild.Wait: TProcessOutput;
var
  LResult: TPlatformProcessResult;
  LDeadline: TInstant;
  LErr: Int32;
  LTimedOut: Boolean;
  LSleepNs: Int64;
begin
  if FWaited then
    Exit(FLastOutput);
  EnsureAttached;

  Result.ExitCode := 0;
  Result.Status := nextpas.core.process.base.psUnknown;
  Result.StdOut := '';
  Result.StdErr := '';
  Result.TimedOut := False;
  Result.OutputLimited := False;
  LTimedOut := False;
  CloseWriterBestEffort(FStdinWriter);
  if FTimeout.IsZero then
  begin
    LErr := platform_process_wait(FProc, LResult);
    if LErr <> 0 then
      RaiseProcessPlatformError('platform_process_wait', LErr);
  end
  else
  begin
    LDeadline := TInstant.Now.Add(FTimeout);
    LSleepNs := 1000000; { 1ms, exponential backoff up to 20ms }
    repeat
      LErr := platform_process_try_wait(FProc, LResult);
      if LErr <> 0 then
        RaiseProcessPlatformError('platform_process_try_wait', LErr);
      if LResult.Status <> nextpas.core.platform.process.base.psRunning then
        Break;
      if TInstant.Now.DurationSince(LDeadline).IsPositive then
      begin
        LErr := platform_process_kill(FProc);
        if LErr <> 0 then
          RaiseProcessPlatformError('platform_process_kill', LErr);
        LErr := platform_process_wait(FProc, LResult);
        if LErr <> 0 then
          RaiseProcessPlatformError('platform_process_wait', LErr);
        LTimedOut := True;
        Break;
      end;
      platform_thread_sleep_ns(LSleepNs);
      if LSleepNs < 20000000 then
      begin
        LSleepNs := LSleepNs * 2;
        if LSleepNs > 20000000 then
          LSleepNs := 20000000;
      end;
    until False;
  end;
  Result := FinishWaitResult(LResult, '', '', LTimedOut);
end;

function TChild.TryWait(out AOutput: TProcessOutput): Boolean;
var
  LResult: TPlatformProcessResult;
  LErr: Int32;
begin
  if FWaited then
  begin
    AOutput := FLastOutput;
    Exit(True);
  end;
  EnsureAttached;

  AOutput.ExitCode := 0;
  AOutput.Status := nextpas.core.process.base.psUnknown;
  AOutput.StdOut := '';
  AOutput.StdErr := '';
  AOutput.TimedOut := False;
  AOutput.OutputLimited := False;
  LErr := platform_process_try_wait(FProc, LResult);
  if LErr <> 0 then
    RaiseProcessPlatformError('platform_process_try_wait', LErr);
  if LResult.Status = nextpas.core.platform.process.base.psRunning then
    Exit(False);
  AOutput := FinishWaitResult(LResult, '', '');
  Result := True;
end;

procedure TChild.Detach;
begin
  CloseWriterBestEffort(FStdinWriter);
  FStdoutReader := nil;
  FStderrReader := nil;
  platform_process_detach(FProc);
  FDetached := True;
end;

procedure TChild.Kill;
var
  LErr: Int32;
begin
  if FWaited then Exit;
  EnsureAttached;
  LErr := platform_process_kill(FProc);
  if LErr <> 0 then
    RaiseProcessPlatformError('platform_process_kill', LErr);
end;

procedure TChild.Signal(ASignal: Integer);
var
  LErr: Int32;
begin
  if FWaited then Exit;
  EnsureAttached;
  LErr := platform_process_signal(FProc, ASignal);
  if LErr <> 0 then
    RaiseProcessPlatformError('platform_process_signal', LErr);
end;

function TChild.Pid: Integer;
begin
  Result := platform_process_pid(FProc);
end;

function TChild.TakeStdin: IWriter;
begin
  Result := FStdinWriter;
  FStdinWriter := nil;
end;

function TChild.TakeStdout: IReader;
begin
  Result := FStdoutReader;
  FStdoutReader := nil;
end;

function TChild.TakeStderr: IReader;
begin
  Result := FStderrReader;
  FStderrReader := nil;
end;

function TChild.WaitWithOutput: TProcessOutput;
const
  DRAIN_TIMEOUT_NS = 5000000000; { 5 seconds after process exit }
  DEFAULT_DRAIN_TIMEOUT_NS = 30000000000; { 30 seconds for no-timeout mode }
var
  LWait: TProcessOutput;
  LProcessResult: TPlatformProcessResult;
  LHaveProcessResult: Boolean;
  LDeadline, LDrainDeadline: TInstant;
  LErr: Int32;
  LStdoutClosed, LStderrClosed: Boolean;
  LTimedOut: Boolean;
  LLimited: Boolean;
begin
  if FWaited then
    Exit(FLastOutput);
  EnsureAttached;

  CloseWriterBestEffort(FStdinWriter);
  Result.StdOut := '';
  Result.StdErr := '';
  Result.TimedOut := False;
  Result.OutputLimited := False;
  LTimedOut := False;
  LLimited := False;
  LHaveProcessResult := False;
  LStdoutClosed := FStdoutReader = nil;
  LStderrClosed := FStderrReader = nil;
  FillChar(LProcessResult, SizeOf(LProcessResult), 0);
  FillChar(LDrainDeadline, SizeOf(LDrainDeadline), 0);
  if not FTimeout.IsZero then
    LDeadline := TInstant.Now.Add(FTimeout);

  repeat
    DrainPipePair(FStdoutReader, FStderrReader, 10, Result.StdOut, Result.StdErr,
      LStdoutClosed, LStderrClosed, FMaxOutput, LLimited);
    if LLimited then
    begin
      { Stop accepting more output: kill child and close parent pipe ends }
      if not LHaveProcessResult then
      begin
        LErr := platform_process_kill(FProc);
        if LErr <> 0 then
          RaiseProcessPlatformError('platform_process_kill', LErr);
        LErr := platform_process_wait(FProc, LProcessResult);
        if LErr <> 0 then
          RaiseProcessPlatformError('platform_process_wait', LErr);
        LHaveProcessResult := True;
      end;
      FStdoutReader := nil;
      FStderrReader := nil;
      LStdoutClosed := True;
      LStderrClosed := True;
      Break;
    end;
    if FTimeout.IsZero then
    begin
      { No explicit timeout: wait for process exit, then drain with safety deadline }
      if not LHaveProcessResult then
      begin
        LErr := platform_process_try_wait(FProc, LProcessResult);
        if LErr <> 0 then
          RaiseProcessPlatformError('platform_process_try_wait', LErr);
        if LProcessResult.Status <> nextpas.core.platform.process.base.psRunning then
        begin
          LHaveProcessResult := True;
          LDrainDeadline := TInstant.Now.Add(
            TDuration.FromNanoseconds(DEFAULT_DRAIN_TIMEOUT_NS));
        end;
      end;
      if LHaveProcessResult and LStdoutClosed and LStderrClosed then
        Break;
      { Force-close pipes if drain takes too long after process exit }
      if LHaveProcessResult and
         TInstant.Now.DurationSince(LDrainDeadline).IsPositive then
      begin
        FStdoutReader := nil;
        FStderrReader := nil;
        LStdoutClosed := True;
        LStderrClosed := True;
        Break;
      end;
      Continue;
    end;

    if not LHaveProcessResult then
    begin
      LErr := platform_process_try_wait(FProc, LProcessResult);
      if LErr <> 0 then
        RaiseProcessPlatformError('platform_process_try_wait', LErr);
      if LProcessResult.Status <> nextpas.core.platform.process.base.psRunning then
      begin
        LHaveProcessResult := True;
        LDrainDeadline := TInstant.Now.Add(TDuration.FromNanoseconds(DRAIN_TIMEOUT_NS));
      end
      else if TInstant.Now.DurationSince(LDeadline).IsPositive then
      begin
        LErr := platform_process_kill(FProc);
        if LErr <> 0 then
          RaiseProcessPlatformError('platform_process_kill', LErr);
        LErr := platform_process_wait(FProc, LProcessResult);
        if LErr <> 0 then
          RaiseProcessPlatformError('platform_process_wait', LErr);
        LHaveProcessResult := True;
        LTimedOut := True;
        LDrainDeadline := TInstant.Now.Add(TDuration.FromNanoseconds(DRAIN_TIMEOUT_NS));
      end;
    end;

    if LHaveProcessResult and LStdoutClosed and LStderrClosed then
      Break;
    { Force-close pipes if drain takes too long after process exit }
    if LHaveProcessResult and TInstant.Now.DurationSince(LDrainDeadline).IsPositive then
    begin
      FStdoutReader := nil;
      FStderrReader := nil;
      LStdoutClosed := True;
      LStderrClosed := True;
      Break;
    end;
    if not LHaveProcessResult then
      platform_thread_sleep_ns(10000000);
  until False;

  if (not FTimeout.IsZero) and (not LHaveProcessResult) then
  begin
    LErr := platform_process_wait(FProc, LProcessResult);
    if LErr <> 0 then
      RaiseProcessPlatformError('platform_process_wait', LErr);
    LHaveProcessResult := True;
  end;

  FStdoutReader := nil;
  FStderrReader := nil;
  if LHaveProcessResult then
    Result := FinishWaitResult(LProcessResult, Result.StdOut, Result.StdErr,
      LTimedOut, LLimited)
  else
  begin
    LWait := Wait;
    Result.ExitCode := LWait.ExitCode;
    Result.Status := LWait.Status;
    Result.TimedOut := LWait.TimedOut or LTimedOut;
    Result.OutputLimited := LLimited or LWait.OutputLimited;
    FLastOutput.StdOut := Result.StdOut;
    FLastOutput.StdErr := Result.StdErr;
    FLastOutput.TimedOut := Result.TimedOut;
    FLastOutput.OutputLimited := Result.OutputLimited;
    Result := FLastOutput;
  end;
end;

function TChild.FinishWaitResult(const AResult: TPlatformProcessResult;
  const AStdOut, AStdErr: string;
  const ATimedOut: Boolean;
  const AOutputLimited: Boolean): TProcessOutput;
begin
  Result.ExitCode := AResult.ExitCode;
  Result.StdOut := AStdOut;
  Result.StdErr := AStdErr;
  Result.TimedOut := ATimedOut;
  Result.OutputLimited := AOutputLimited;
  case AResult.Status of
    psExited: Result.Status := nextpas.core.process.base.psExited;
    psSignaled: Result.Status := nextpas.core.process.base.psSignaled;
    psRunning: Result.Status := nextpas.core.process.base.psRunning;
  else
    Result.Status := nextpas.core.process.base.psUnknown;
  end;
  FLastOutput := Result;
  FWaited := True;
end;

end.
