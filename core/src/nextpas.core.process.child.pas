unit nextpas.core.process.child;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
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
  IChild = interface
    ['{A1B2C3D4-E5F6-7890-AB01-000000000001}']
    {** 阻塞等待子进程退出，返回退出状态 *}
    function Wait: TProcessOutput;
    {** 非阻塞检查子进程是否已退出。返回 False 表示仍在运行 *}
    function TryWait(out AOutput: TProcessOutput): Boolean;
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
  public
    constructor Create(const AProc: TPlatformProcess;
      const AStdin: IWriter; const AStdout: IReader; const AStderr: IReader);
    destructor Destroy; override;
    function Wait: TProcessOutput;
    function TryWait(out AOutput: TProcessOutput): Boolean;
    procedure Kill;
    function Pid: Integer;
    function TakeStdin: IWriter;
    function TakeStdout: IReader;
    function TakeStderr: IReader;
    function WaitWithOutput: TProcessOutput;
  end;

implementation

uses
  nextpas.core.platform.process,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.process.pipe;

const
  READ_BUF_SIZE = 65536;

function ReadAll(const AReader: IReader): string;
var
  LBuf: array[0..READ_BUF_SIZE - 1] of Byte;
  LRead: SizeUInt;
  LTotal: Integer;
begin
  Result := '';
  if AReader = nil then Exit;
  LTotal := 0;
  repeat
    LRead := AReader.Read(LBuf[0], READ_BUF_SIZE);
    if LRead > 0 then
    begin
      SetLength(Result, LTotal + Integer(LRead));
      Move(LBuf[0], Result[LTotal + 1], LRead);
      Inc(LTotal, Integer(LRead));
    end;
  until LRead = 0;
end;

{ TChild }

constructor TChild.Create(const AProc: TPlatformProcess;
  const AStdin: IWriter; const AStdout: IReader; const AStderr: IReader);
begin
  inherited Create;
  FProc := AProc;
  FStdinWriter := AStdin;
  FStdoutReader := AStdout;
  FStderrReader := AStderr;
  FWaited := False;
end;

destructor TChild.Destroy;
var
  LResult: TPlatformProcessResult;
begin
  if not FWaited then
  begin
    Kill;
    platform_process_wait(FProc, LResult);
  end;
  if FStdinWriter <> nil then
    (FStdinWriter as TPipeWriter).Close;
  FStdinWriter := nil;
  FStdoutReader := nil;
  FStderrReader := nil;
  inherited;
end;

function TChild.Wait: TProcessOutput;
var
  LResult: TPlatformProcessResult;
begin
  FillChar(Result, SizeOf(Result), 0);
  if FStdinWriter <> nil then
    (FStdinWriter as TPipeWriter).Close;
  FStdinWriter := nil;
  platform_process_wait(FProc, LResult);
  FWaited := True;
  Result.ExitCode := LResult.ExitCode;
  case LResult.Status of
    psExited: Result.Status := nextpas.core.process.base.psExited;
    psSignaled: Result.Status := nextpas.core.process.base.psSignaled;
    psRunning: Result.Status := nextpas.core.process.base.psRunning;
  else
    Result.Status := nextpas.core.process.base.psUnknown;
  end;
end;

function TChild.TryWait(out AOutput: TProcessOutput): Boolean;
var
  LResult: TPlatformProcessResult;
begin
  FillChar(AOutput, SizeOf(AOutput), 0);
  platform_process_try_wait(FProc, LResult);
  if LResult.Status = nextpas.core.platform.process.base.psRunning then
    Exit(False);
  FWaited := True;
  AOutput.ExitCode := LResult.ExitCode;
  case LResult.Status of
    psExited: AOutput.Status := nextpas.core.process.base.psExited;
    psSignaled: AOutput.Status := nextpas.core.process.base.psSignaled;
  else
    AOutput.Status := nextpas.core.process.base.psUnknown;
  end;
  Result := True;
end;

procedure TChild.Kill;
begin
  if FWaited then Exit;
  platform_process_kill(FProc);
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
var
  LWait: TProcessOutput;
  LFds: array[0..1] of TPollFd;
  LNFds: Integer;
  LBuf: array[0..65535] of Byte;
  LRead: ssize_t;
  LOutTotal, LErrTotal: Integer;
  LStdoutFd, LStderrFd: PtrInt;
  LPollResult: Integer;
begin
  if FStdinWriter <> nil then
    (FStdinWriter as TPipeWriter).Close;
  FStdinWriter := nil;
  Result.StdOut := '';
  Result.StdErr := '';
  LOutTotal := 0;
  LErrTotal := 0;

  LStdoutFd := -1;
  LStderrFd := -1;
  if (FStdoutReader <> nil) and (FStdoutReader is TPipeReader) then
    LStdoutFd := TPipeReader(FStdoutReader as TObject).Fd;
  if (FStderrReader <> nil) and (FStderrReader is TPipeReader) then
    LStderrFd := TPipeReader(FStderrReader as TObject).Fd;

  if (LStdoutFd >= 0) and (LStderrFd >= 0) then
  begin
    repeat
      LNFds := 0;
      if LStdoutFd >= 0 then
      begin
        LFds[LNFds].fd := LStdoutFd;
        LFds[LNFds].events := POLLIN;
        LFds[LNFds].revents := 0;
        Inc(LNFds);
      end;
      if LStderrFd >= 0 then
      begin
        LFds[LNFds].fd := LStderrFd;
        LFds[LNFds].events := POLLIN;
        LFds[LNFds].revents := 0;
        Inc(LNFds);
      end;
      if LNFds = 0 then Break;

      LPollResult := poll(@LFds[0], LNFds, -1);
      if LPollResult <= 0 then Break;

      if (LStdoutFd >= 0) and ((LFds[0].revents and (POLLIN or POLLHUP)) <> 0) then
      begin
        LRead := read(LStdoutFd, @LBuf[0], SizeOf(LBuf));
        if LRead > 0 then
        begin
          SetLength(Result.StdOut, LOutTotal + LRead);
          Move(LBuf[0], Result.StdOut[LOutTotal + 1], LRead);
          Inc(LOutTotal, LRead);
        end
        else
          LStdoutFd := -1;
      end;

      if (LStderrFd >= 0) then
      begin
        if (LNFds = 2) and ((LFds[1].revents and (POLLIN or POLLHUP)) <> 0) then
        begin
          LRead := read(LStderrFd, @LBuf[0], SizeOf(LBuf));
          if LRead > 0 then
          begin
            SetLength(Result.StdErr, LErrTotal + LRead);
            Move(LBuf[0], Result.StdErr[LErrTotal + 1], LRead);
            Inc(LErrTotal, LRead);
          end
          else
            LStderrFd := -1;
        end
        else if (LNFds = 1) and ((LFds[0].revents and (POLLIN or POLLHUP)) <> 0) then
        begin
          LRead := read(LStderrFd, @LBuf[0], SizeOf(LBuf));
          if LRead > 0 then
          begin
            SetLength(Result.StdErr, LErrTotal + LRead);
            Move(LBuf[0], Result.StdErr[LErrTotal + 1], LRead);
            Inc(LErrTotal, LRead);
          end
          else
            LStderrFd := -1;
        end;
      end;
    until (LStdoutFd < 0) and (LStderrFd < 0);
  end
  else
  begin
    Result.StdOut := ReadAll(FStdoutReader);
    Result.StdErr := ReadAll(FStderrReader);
  end;

  FStdoutReader := nil;
  FStderrReader := nil;
  LWait := Wait;
  Result.ExitCode := LWait.ExitCode;
  Result.Status := LWait.Status;
end;

end.
