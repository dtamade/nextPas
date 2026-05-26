unit nextpas.core.thread.pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.base,
  nextpas.core.thread.intf;

function CreateThreadPool(const AWorkerCount: Integer = 0): IThreadPool;

implementation

uses
  SysUtils,
  nextpas.core.platform.thread,
  nextpas.core.platform.sync;

type
  PTaskNode = ^TTaskNode;
  TTaskNode = record
    Task: TThreadTask;
    Next: PTaskNode;
  end;

  TThreadPool = class(TInterfacedObject, IThreadPool)
  private
    FMutex: TPlatformMutex;
    FCondVar: TPlatformCondVar;
    FDoneCondVar: TPlatformCondVar;
    FHead: PTaskNode;
    FTail: PTaskNode;
    FWorkerCount: Integer;
    FWorkers: array of TPlatformThreadHandle;
    FShutdown: Boolean;
    FPendingTasks: Integer;
  public
    constructor Create(const AWorkerCount: Integer);
    destructor Destroy; override;
    procedure Submit(const ATask: TThreadTask);
    procedure Shutdown;
    procedure WaitAll;
    function GetWorkerCount: Integer;
  end;

function WorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LPool: TThreadPool;
  LNode: PTaskNode;
  LTask: TThreadTask;
begin
  Result := nil;
  LPool := TThreadPool(AArg);

  while True do
  begin
    platform_mutex_lock(LPool.FMutex);

    while (LPool.FHead = nil) and (not LPool.FShutdown) do
      platform_condvar_wait(LPool.FCondVar, LPool.FMutex);

    if (LPool.FHead = nil) and LPool.FShutdown then
    begin
      platform_mutex_unlock(LPool.FMutex);
      Break;
    end;

    LNode := LPool.FHead;
    LPool.FHead := LNode^.Next;
    if LPool.FHead = nil then
      LPool.FTail := nil;

    platform_mutex_unlock(LPool.FMutex);

    LTask := LNode^.Task;
    LNode^.Task := nil;
    Dispose(LNode);

    try
      LTask();
    except
    end;
    LTask := nil;

    platform_mutex_lock(LPool.FMutex);
    Dec(LPool.FPendingTasks);
    if LPool.FPendingTasks = 0 then
      platform_condvar_broadcast(LPool.FDoneCondVar);
    platform_mutex_unlock(LPool.FMutex);
  end;
end;

{ TThreadPool }

constructor TThreadPool.Create(const AWorkerCount: Integer);
var
  LI: Integer;
  LCount: Integer;
begin
  inherited Create;
  FHead := nil;
  FTail := nil;
  FShutdown := False;
  FPendingTasks := 0;

  platform_mutex_init(FMutex);
  platform_condvar_init(FCondVar);
  platform_condvar_init(FDoneCondVar);

  if AWorkerCount > 0 then
    LCount := AWorkerCount
  else
    LCount := platform_cpu_count;

  FWorkerCount := LCount;
  SetLength(FWorkers, LCount);

  for LI := 0 to LCount - 1 do
    platform_thread_create(FWorkers[LI], @WorkerProc, Self);
end;

destructor TThreadPool.Destroy;
begin
  Shutdown;
  inherited Destroy;
end;

procedure TThreadPool.Submit(const ATask: TThreadTask);
var
  LNode: PTaskNode;
begin
  platform_mutex_lock(FMutex);

  if FShutdown then
  begin
    platform_mutex_unlock(FMutex);
    Exit;
  end;

  New(LNode);
  LNode^.Task := ATask;
  LNode^.Next := nil;

  if FTail <> nil then
    FTail^.Next := LNode
  else
    FHead := LNode;
  FTail := LNode;
  Inc(FPendingTasks);

  platform_mutex_unlock(FMutex);
  platform_condvar_signal(FCondVar);
end;

procedure TThreadPool.Shutdown;
var
  LI: Integer;
  LRetVal: Pointer;
begin
  platform_mutex_lock(FMutex);
  if FShutdown then
  begin
    platform_mutex_unlock(FMutex);
    Exit;
  end;
  FShutdown := True;
  platform_mutex_unlock(FMutex);

  platform_condvar_broadcast(FCondVar);

  for LI := 0 to FWorkerCount - 1 do
    platform_thread_join(FWorkers[LI], LRetVal);
end;

procedure TThreadPool.WaitAll;
begin
  platform_mutex_lock(FMutex);
  while FPendingTasks > 0 do
    platform_condvar_wait(FDoneCondVar, FMutex);
  platform_mutex_unlock(FMutex);
end;

function TThreadPool.GetWorkerCount: Integer;
begin
  Result := FWorkerCount;
end;

function CreateThreadPool(const AWorkerCount: Integer): IThreadPool;
begin
  Result := TThreadPool.Create(AWorkerCount);
end;

end.
