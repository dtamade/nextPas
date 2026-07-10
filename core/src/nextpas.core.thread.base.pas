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
    property Terminated: Boolean read GetTerminated;
    property ReturnValue: Pointer read FReturnValue;
  end;

implementation

function WorkerThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LThread: TWorkerThread;
begin
  Result := nil;
  LThread := TWorkerThread(AArg);
  try
    LThread.Execute;
  except
    { Swallow exceptions in thread proc }
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
end;

destructor TWorkerThread.Destroy;
begin
  if FHandle <> nil then
    platform_thread_detach(FHandle);
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

procedure TWorkerThread.DoTerminate;
begin
  { Override to handle thread termination }
end;

end.
