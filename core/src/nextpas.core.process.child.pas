unit nextpas.core.process.child;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.process.base,
  nextpas.core.platform.process.base,
  nextpas.core.async.cancellation;

type
  {**
   * IChild
   *
   * @desc 正在运行的子进程句柄
   *
   * @note Destroy：尽力 Kill + reap（最长约 5s）；超时则 abandon 再 detach，不保证无僵尸
   * @note Wait：若 IChild 仍持有 stdout/stderr 管道，自动走 WaitWithOutput 排水，避免管道写满死锁
   * @note TryWait：进程已退出且仍持有管道时同样排水（与 Wait 一致，避免输出丢失）
   * @note TakeStdout/TakeStderr 后由调用方排水；裸 Wait/TryWait 不再负责已取走的端
   * @note 捕获输出优先 WaitWithOutput；大输出请 Take* 流式读
   *}
  {** @note 非线程安全。IChild 的所有方法必须在同一线程调用 *}
  IChild = interface
    ['{A1B2C3D4-E5F6-7890-AB01-000000000001}']
    {** 阻塞等待子进程退出。仍持有管道时自动排水（等同 WaitWithOutput） *}
    function Wait: TProcessOutput;
    {** 非阻塞检查。已退出且仍持有管道时**仅排水**后返回 True（不二次 wait） *}
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
    {**
     * @desc 先 SIGTERM，在 AGrace 内等待退出；超时则 Kill 再 reap（对齐 Go WaitDelay 意图）
     * @note 仍持管道时在 reaped 后排水（同 TryWait drain-only）
     * @note TimedOut=True 表示 grace 耗尽并走了 Kill
     *}
    function WaitGraceful(const AGrace: TDuration): TProcessOutput;
    {** 进程组 ID：NewProcessGroup 时等于 Pid；否则 0 *}
    function ProcessGroupId: Integer;
    {** 向进程组发 SIGKILL；未建组时等价 Kill *}
    procedure KillTree;
    {** 向进程组发信号；未建组时等价 Signal *}
    procedure SignalTree(ASignal: Integer);
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
    FCancelToken: IAsyncCancellationToken;
    FNewProcessGroup: Boolean;
    FLastOutput: TProcessOutput;
    procedure EnsureAttached;
    procedure RaiseProcessPlatformError(const AOp: string; ACode: Int32);
    function FinishWaitResult(const AResult: TPlatformProcessResult;
      const AStdOut, AStdErr: string;
      const ATimedOut: Boolean = False;
      const AOutputLimited: Boolean = False;
      const ACancelled: Boolean = False): TProcessOutput;
    function DrainOwnedPipesAfterReap(const AResult: TPlatformProcessResult;
      const ATimedOut: Boolean;
      const ACancelled: Boolean = False): TProcessOutput;
    function CancelRequested: Boolean;
  public
    constructor Create(const AProc: TPlatformProcess;
      const AStdin: IWriter; const AStdout: IReader; const AStderr: IReader;
      const ATimeout: TDuration; const AMaxOutput: Int64 = 0;
      const ACancelToken: IAsyncCancellationToken = nil;
      const ANewProcessGroup: Boolean = False);
    destructor Destroy; override;
    function Wait: TProcessOutput;
    function TryWait(out AOutput: TProcessOutput): Boolean;
    procedure Detach;
    procedure Kill;
    procedure Signal(ASignal: Integer);
    function Pid: Integer;
    function ProcessGroupId: Integer;
    procedure KillTree;
    procedure SignalTree(ASignal: Integer);
    function TakeStdin: IWriter;
    function TakeStdout: IReader;
    function TakeStderr: IReader;
    function WaitWithOutput: TProcessOutput;
    function WaitGraceful(const AGrace: TDuration): TProcessOutput;
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
  const ATimeout: TDuration; const AMaxOutput: Int64;
  const ACancelToken: IAsyncCancellationToken;
  const ANewProcessGroup: Boolean);
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
  FCancelToken := ACancelToken;
  FNewProcessGroup := ANewProcessGroup;
  FillChar(FLastOutput, SizeOf(FLastOutput), 0);
end;

function TChild.CancelRequested: Boolean;
begin
  Result := (FCancelToken <> nil) and FCancelToken.IsCancelled;
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
  LKillOk: Boolean;
begin
  if (not FWaited) and (not FDetached) then
  begin
    if platform_process_try_wait(FProc, LResult) = 0 then
      if LResult.Status = nextpas.core.platform.process.base.psRunning then
      begin
        if FNewProcessGroup then
          LKillOk := platform_process_kill_group(platform_process_pid(FProc), 9) = 0
        else
          LKillOk := platform_process_kill(FProc) = 0;
        if LKillOk then
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
  LCancelled: Boolean;
  LSleepNs: Int64;
  LHaveDeadline: Boolean;
begin
  if FWaited then
    Exit(FLastOutput);
  { Own pipes still held → drain while reaping (INV-13). Take* clears readers. }
  if (FStdoutReader <> nil) or (FStderrReader <> nil) then
    Exit(WaitWithOutput);
  EnsureAttached;

  Result.ExitCode := 0;
  Result.Status := nextpas.core.process.base.psUnknown;
  Result.StdOut := '';
  Result.StdErr := '';
  Result.TimedOut := False;
  Result.OutputLimited := False;
  Result.Cancelled := False;
  LTimedOut := False;
  LCancelled := False;
  CloseWriterBestEffort(FStdinWriter);
  LHaveDeadline := not FTimeout.IsZero;
  if LHaveDeadline then
    LDeadline := TInstant.Now.Add(FTimeout);

  { Blocking wait only when nothing to poll (no timeout, no cancel token). }
  if (not LHaveDeadline) and (FCancelToken = nil) then
  begin
    LErr := platform_process_wait(FProc, LResult);
    if LErr <> 0 then
      RaiseProcessPlatformError('platform_process_wait', LErr);
  end
  else
  begin
    LSleepNs := 1000000; { 1ms, exponential backoff up to 20ms }
    repeat
      if CancelRequested then
      begin
        LErr := platform_process_kill(FProc);
        if LErr <> 0 then
          RaiseProcessPlatformError('platform_process_kill', LErr);
        LErr := platform_process_wait(FProc, LResult);
        if LErr <> 0 then
          RaiseProcessPlatformError('platform_process_wait', LErr);
        LCancelled := True;
        Break;
      end;
      LErr := platform_process_try_wait(FProc, LResult);
      if LErr <> 0 then
        RaiseProcessPlatformError('platform_process_try_wait', LErr);
      if LResult.Status <> nextpas.core.platform.process.base.psRunning then
        Break;
      if LHaveDeadline and TInstant.Now.DurationSince(LDeadline).IsPositive then
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
  Result := FinishWaitResult(LResult, '', '', LTimedOut, False, LCancelled);
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
  AOutput := DrainOwnedPipesAfterReap(LResult, False);
  Result := True;
end;

function TChild.DrainOwnedPipesAfterReap(const AResult: TPlatformProcessResult;
  const ATimedOut: Boolean;
  const ACancelled: Boolean): TProcessOutput;
var
  LStdoutClosed, LStderrClosed: Boolean;
  LLimited: Boolean;
  LStdOut, LStdErr: string;
begin
  if (FStdoutReader <> nil) or (FStderrReader <> nil) then
  begin
    CloseWriterBestEffort(FStdinWriter);
    LStdOut := '';
    LStdErr := '';
    LLimited := False;
    LStdoutClosed := FStdoutReader = nil;
    LStderrClosed := FStderrReader = nil;
    while not (LStdoutClosed and LStderrClosed) do
    begin
      DrainPipePair(FStdoutReader, FStderrReader, 10, LStdOut, LStdErr,
        LStdoutClosed, LStderrClosed, FMaxOutput, LLimited);
      if LLimited then
        Break;
    end;
    FStdoutReader := nil;
    FStderrReader := nil;
    Exit(FinishWaitResult(AResult, LStdOut, LStdErr, ATimedOut, LLimited, ACancelled));
  end;
  Result := FinishWaitResult(AResult, '', '', ATimedOut, False, ACancelled);
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

function TChild.ProcessGroupId: Integer;
begin
  if FNewProcessGroup then
    Result := platform_process_pid(FProc)
  else
    Result := 0;
end;

procedure TChild.KillTree;
const
  SIGKILL = 9;
var
  LErr: Int32;
  LPgid: Int32;
begin
  if FWaited then Exit;
  EnsureAttached;
  if not FNewProcessGroup then
  begin
    Kill;
    Exit;
  end;
  LPgid := platform_process_pid(FProc);
  LErr := platform_process_kill_group(LPgid, SIGKILL);
  if LErr <> 0 then
    RaiseProcessPlatformError('platform_process_kill_group', LErr);
end;

procedure TChild.SignalTree(ASignal: Integer);
var
  LErr: Int32;
  LPgid: Int32;
begin
  if FWaited then Exit;
  EnsureAttached;
  if not FNewProcessGroup then
  begin
    Signal(ASignal);
    Exit;
  end;
  LPgid := platform_process_pid(FProc);
  LErr := platform_process_kill_group(LPgid, ASignal);
  if LErr <> 0 then
    RaiseProcessPlatformError('platform_process_kill_group', LErr);
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
  LCancelled: Boolean;
  LPollMs: Int32;
begin
  if FWaited then
    Exit(FLastOutput);
  EnsureAttached;

  CloseWriterBestEffort(FStdinWriter);
  Result.StdOut := '';
  Result.StdErr := '';
  Result.TimedOut := False;
  Result.OutputLimited := False;
  Result.Cancelled := False;
  LTimedOut := False;
  LLimited := False;
  LCancelled := False;
  LHaveProcessResult := False;
  LStdoutClosed := FStdoutReader = nil;
  LStderrClosed := FStderrReader = nil;
  FillChar(LProcessResult, SizeOf(LProcessResult), 0);
  FillChar(LDrainDeadline, SizeOf(LDrainDeadline), 0);
  if not FTimeout.IsZero then
    LDeadline := TInstant.Now.Add(FTimeout);

  repeat
    if (not LHaveProcessResult) and CancelRequested then
    begin
      LErr := platform_process_kill(FProc);
      if LErr <> 0 then
        RaiseProcessPlatformError('platform_process_kill', LErr);
      LErr := platform_process_wait(FProc, LProcessResult);
      if LErr <> 0 then
        RaiseProcessPlatformError('platform_process_wait', LErr);
      LHaveProcessResult := True;
      LCancelled := True;
      LDrainDeadline := TInstant.Now.Add(TDuration.FromNanoseconds(DRAIN_TIMEOUT_NS));
    end;
    if LHaveProcessResult then
      LPollMs := 0
    else
      LPollMs := 1;
    DrainPipePair(FStdoutReader, FStderrReader, LPollMs, Result.StdOut, Result.StdErr,
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
      { Short backoff while process still running (was 10ms). }
      if not LHaveProcessResult then
        platform_thread_sleep_ns(100000);
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
      platform_thread_sleep_ns(100000);
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
      LTimedOut, LLimited, LCancelled)
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

function TChild.WaitGraceful(const AGrace: TDuration): TProcessOutput;
const
  SIGTERM = 15;
  SIGKILL = 9;
var
  LResult: TPlatformProcessResult;
  LDeadline: TInstant;
  LErr: Int32;
  LTimedOut: Boolean;
  LCancelled: Boolean;
  LSleepNs: Int64;
begin
  if FWaited then
    Exit(FLastOutput);
  EnsureAttached;

  LTimedOut := False;
  LCancelled := False;
  { Process group: signal whole tree so grandchildren exit with the leader. }
  if FNewProcessGroup then
    SignalTree(SIGTERM)
  else
    Signal(SIGTERM);
  if AGrace.IsZero or AGrace.IsNegative then
    LDeadline := TInstant.Now
  else
    LDeadline := TInstant.Now.Add(AGrace);
  LSleepNs := 1000000;
  FillChar(LResult, SizeOf(LResult), 0);
  repeat
    if CancelRequested then
    begin
      LCancelled := True;
      if FNewProcessGroup then
        LErr := platform_process_kill_group(platform_process_pid(FProc), SIGKILL)
      else
        LErr := platform_process_kill(FProc);
      if LErr <> 0 then
        RaiseProcessPlatformError('platform_process_kill', LErr);
      LErr := platform_process_wait(FProc, LResult);
      if LErr <> 0 then
        RaiseProcessPlatformError('platform_process_wait', LErr);
      Break;
    end;
    LErr := platform_process_try_wait(FProc, LResult);
    if LErr <> 0 then
      RaiseProcessPlatformError('platform_process_try_wait', LErr);
    if LResult.Status <> nextpas.core.platform.process.base.psRunning then
      Break;
    if TInstant.Now.DurationSince(LDeadline).IsPositive then
    begin
      LTimedOut := True;
      if FNewProcessGroup then
        LErr := platform_process_kill_group(platform_process_pid(FProc), SIGKILL)
      else
        LErr := platform_process_kill(FProc);
      if LErr <> 0 then
        RaiseProcessPlatformError('platform_process_kill', LErr);
      LErr := platform_process_wait(FProc, LResult);
      if LErr <> 0 then
        RaiseProcessPlatformError('platform_process_wait', LErr);
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
  Result := DrainOwnedPipesAfterReap(LResult, LTimedOut, LCancelled);
end;

function TChild.FinishWaitResult(const AResult: TPlatformProcessResult;
  const AStdOut, AStdErr: string;
  const ATimedOut: Boolean;
  const AOutputLimited: Boolean;
  const ACancelled: Boolean): TProcessOutput;
begin
  Result.ExitCode := AResult.ExitCode;
  Result.StdOut := AStdOut;
  Result.StdErr := AStdErr;
  Result.TimedOut := ATimedOut;
  Result.OutputLimited := AOutputLimited;
  Result.Cancelled := ACancelled;
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
