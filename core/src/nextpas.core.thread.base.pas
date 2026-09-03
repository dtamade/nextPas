unit nextpas.core.thread.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.thread,
  nextpas.core.exception;

type
  TThreadTask = reference to procedure;

  TFutureState = (
    fsPending,
    fsCompleted,
    fsFailed,
    fsCancelled
  );

  { TWorkerThread — nextpas-owned thread wrapper
    Replaces FPC's TThread. Uses platform_thread_create internally.
    Exceptions raised by Execute are captured on the object (not silently
    dropped); after WaitFor (or once the thread has exited) callers can
    inspect HasException / ExceptionMessage, or re-raise via RethrowIfFailed.
    Usage:
      type TMyThread = class(TWorkerThread)
        procedure Execute; override;
      end;
    }
  TWorkerThread = class
  private
    FHandle: TPlatformThreadHandle;
    FTerminated: Boolean;
    FReturnValue: Pointer;
    FException: Exception;  { captured from Execute; owned by this object }
    function GetTerminated: Boolean;
  protected
    procedure Execute; virtual; abstract;
    procedure DoTerminate; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure WaitFor;
    procedure Terminate;
    { True if Execute raised; only meaningful after the thread has exited. }
    function HasException: Boolean;
    { Message of the captured exception; '' when none. Logging/diagnostics only. }
    function ExceptionMessage: string;
    { Re-raise the captured exception and transfer ownership (HasException
      becomes False). No-op when there was no exception. Call after WaitFor. }
    procedure RethrowIfFailed;
    property Terminated: Boolean read GetTerminated;
    property ReturnValue: Pointer read FReturnValue;
  end;

implementation

{ AcquireExceptionObject via nextpas.core.exception single-source inline wrapper
  (System.AcquireExceptionObject zero-copy forward, no SysUtils bridge) }

function WorkerThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LThread: TWorkerThread;
begin
  Result := nil;
  LThread := TWorkerThread(AArg);
  try
    LThread.Execute;
  except
    on LE: Exception do
    begin
      { 接管异常所有权：FPC 在离开 except 块时会自动释放异常对象，
        AcquireExceptionObject 把析构责任转移给这里（thread 对象）。
        默认行为由「不吞」改为「捕获保存」——线程异常必须可观察。 }
      LThread.FException := Exception(AcquireExceptionObject);
    end;
  end;
  LThread.FTerminated := True;
  LThread.DoTerminate;
end;

{ TWorkerThread }

constructor TWorkerThread.Create;
begin
  inherited Create;
  FTerminated := False;
  FReturnValue := nil;
  FException := nil;
end;

destructor TWorkerThread.Destroy;
var
  LE: Exception;
begin
  if FHandle <> nil then
    platform_thread_detach(FHandle);
  { 未被 RethrowIfFailed 消费的已捕获异常：在此释放，避免泄漏。
    仅当线程已退出（WaitFor 后）才有意义；见接口注释。 }
  if FException <> nil then
  begin
    LE := FException;
    FException := nil;
    LE.Free;
  end;
  inherited Destroy;
end;

procedure TWorkerThread.Start;
var
  LErr: Int32;
begin
  LErr := platform_thread_create(FHandle, @WorkerThreadProc, Self);
  if LErr <> 0 then
    raise EInvalidOperationError.Create('TWorkerThread: failed to create thread');
end;

procedure TWorkerThread.WaitFor;
var
  LRetVal: Pointer;
begin
  if FHandle <> nil then
  begin
    platform_thread_join(FHandle, LRetVal);
    FHandle := nil;
  end;
end;

procedure TWorkerThread.Terminate;
begin
  FTerminated := True;
end;

function TWorkerThread.GetTerminated: Boolean;
begin
  Result := FTerminated;
end;

function TWorkerThread.HasException: Boolean;
begin
  Result := FException <> nil;
end;

function TWorkerThread.ExceptionMessage: string;
begin
  if FException <> nil then
    Result := FException.Message
  else
    Result := '';
end;

procedure TWorkerThread.RethrowIfFailed;
var
  LE: Exception;
begin
  if FException = nil then
    Exit;
  { 取出并转移所有权：调用方负责释放（重新抛出的异常由调用方解旋）。
    FException 先置 nil，避免 raise 后本对象被 Free 时二次释放。 }
  LE := FException;
  FException := nil;
  raise LE;
end;

procedure TWorkerThread.DoTerminate;
begin
  { Override to handle thread termination }
end;

end.
