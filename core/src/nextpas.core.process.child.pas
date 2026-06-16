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
    FLastOutput: TProcessOutput;
    procedure EnsureAttached;
    procedure RaiseProcessPlatformError(const AOp: string; ACode: Int32);
    function FinishWaitResult(const AResult: TPlatformProcessResult;
      const AStdOut, AStdErr: string): TProcessOutput;
  public
    constructor Create(const AProc: TPlatformProcess;
      const AStdin: IWriter; const AStdout: IReader; const AStderr: IReader;
      const ATimeout: TDuration);
    destructor Destroy; override;
    function Wait: TProcessOutput;
    function TryWait(out AOutput: TProcessOutput): Boolean;
    procedure Detach;
    procedure Kill;
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
  const ATimeout: TDuration);
begin
  inherited Create;
  FProc := AProc;
  FStdinWriter := AStdin;
  FStdoutReader := AStdout;
  FStderrReader := AStderr;
  FWaited := False;
  FDetached := False;
  FTimeout := ATimeout;
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
begin
  if FWaited then
    Exit(FLastOutput);
  EnsureAttached;

  Result.ExitCode := 0;
  Result.Status := nextpas.core.process.base.psUnknown;
  Result.StdOut := '';
  Result.StdErr := '';
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
        Break;
      end;
      platform_thread_sleep_ns(10000000);
    until False;
  end;
  Result := FinishWaitResult(LResult, '', '');
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
var
  LWait: TProcessOutput;
  LProcessResult: TPlatformProcessResult;
  LHaveProcessResult: Boolean;
  LDeadline, LDrainDeadline: TInstant;
  LErr: Int32;
  LStdoutClosed, LStderrClosed: Boolean;
begin
  if FWaited then
    Exit(FLastOutput);
  EnsureAttached;

  CloseWriterBestEffort(FStdinWriter);
  Result.StdOut := '';
  Result.StdErr := '';
  LHaveProcessResult := False;
  LStdoutClosed := FStdoutReader = nil;
  LStderrClosed := FStderrReader = nil;
  FillChar(LProcessResult, SizeOf(LProcessResult), 0);
  FillChar(LDrainDeadline, SizeOf(LDrainDeadline), 0);
  if not FTimeout.IsZero then
    LDeadline := TInstant.Now.Add(FTimeout);

  repeat
    DrainPipePair(FStdoutReader, FStderrReader, 10, Result.StdOut, Result.StdErr,
      LStdoutClosed, LStderrClosed);
    if FTimeout.IsZero then
    begin
      if LStdoutClosed and LStderrClosed then
        Break;
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
    Result := FinishWaitResult(LProcessResult, Result.StdOut, Result.StdErr)
  else
  begin
    LWait := Wait;
    Result.ExitCode := LWait.ExitCode;
    Result.Status := LWait.Status;
    FLastOutput.StdOut := Result.StdOut;
    FLastOutput.StdErr := Result.StdErr;
    Result := FLastOutput;
  end;
end;

function TChild.FinishWaitResult(const AResult: TPlatformProcessResult;
  const AStdOut, AStdErr: string): TProcessOutput;
begin
  Result.ExitCode := AResult.ExitCode;
  Result.StdOut := AStdOut;
  Result.StdErr := AStdErr;
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
