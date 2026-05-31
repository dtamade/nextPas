unit nextpas.core.thread.pool.worksteal;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.base,
  nextpas.core.thread.intf;

{**
 * CreateWorkStealingPool - work-stealing 线程池
 *
 * @desc
 *   支持 reference to procedure / procedure of object / plain procedure。
 *   每个 worker 有独立队列，空闲时从其他 worker 偷取。
 *   跨平台（POSIX pthread / Windows threads via platform layer）。
 *}
function CreateWorkStealingPool(const AWorkerCount: Integer = 0): IThreadPool;

implementation

uses
  nextpas.core.base,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.sync.condvar,
  nextpas.core.platform.thread;

const
  QUEUE_CAPACITY = 4096;
  MAX_WORKERS = 64;

type
  TTaskQueue = record
    Tasks: array[0..QUEUE_CAPACITY - 1] of TThreadTask;
    Head: Integer;
    Tail: Integer;
    Count: Integer;
  end;

  TWorkStealingPool = class;

  PWorkerCtx = ^TWorkerCtx;
  TWorkerCtx = record
    Pool: TWorkStealingPool;
    ID: Integer;
  end;

  TWorkStealingPool = class(TInterfacedObject, IThreadPool)
  private
    FQueues: array[0..MAX_WORKERS - 1] of TTaskQueue;
    FContexts: array[0..MAX_WORKERS - 1] of TWorkerCtx;
    FWorkerCount: Integer;
    FWorkers: array[0..MAX_WORKERS - 1] of TPlatformThreadHandle;
    FMutex: IMutex;
    FCondVar: ICondVar;
    FDoneCondVar: ICondVar;
    FShutdown: Boolean;
    FPendingTasks: Integer;
    FNextQueue: Integer;
  public
    constructor Create(const AWorkerCount: Integer);
    destructor Destroy; override;
    procedure Submit(const ATask: TThreadTask);
    procedure Shutdown;
    procedure WaitAll;
    function GetWorkerCount: Integer;
  end;

function WorkerMain(AArg: Pointer): Pointer; cdecl;
var
  LPool: TWorkStealingPool;
  LMyID, LVictim, LI: Integer;
  LTask: TThreadTask;
  LFound: Boolean;
begin
  Result := nil;
  LPool := PWorkerCtx(AArg)^.Pool;
  LMyID := PWorkerCtx(AArg)^.ID;

  while True do
  begin
    LTask := nil;
    LFound := False;

    LPool.FMutex.Acquire;

    // Try own queue (pop from front)
    if LPool.FQueues[LMyID].Count > 0 then
    begin
      Pointer(LTask) := Pointer(LPool.FQueues[LMyID].Tasks[LPool.FQueues[LMyID].Head]);
      Pointer(LPool.FQueues[LMyID].Tasks[LPool.FQueues[LMyID].Head]) := nil;
      LPool.FQueues[LMyID].Head := (LPool.FQueues[LMyID].Head + 1) mod QUEUE_CAPACITY;
      Dec(LPool.FQueues[LMyID].Count);
      LFound := True;
    end;

    // Try stealing from back of victim's queue
    if not LFound then
      for LI := 1 to LPool.FWorkerCount - 1 do
      begin
        LVictim := (LMyID + LI) mod LPool.FWorkerCount;
        if LPool.FQueues[LVictim].Count > 0 then
        begin
          // Pop from back: decrement Tail
          LPool.FQueues[LVictim].Tail := (LPool.FQueues[LVictim].Tail - 1 + QUEUE_CAPACITY) mod QUEUE_CAPACITY;
          Dec(LPool.FQueues[LVictim].Count);
          Pointer(LTask) := Pointer(LPool.FQueues[LVictim].Tasks[LPool.FQueues[LVictim].Tail]);
          Pointer(LPool.FQueues[LVictim].Tasks[LPool.FQueues[LVictim].Tail]) := nil;
          LFound := True;
          Break;
        end;
      end;

    LPool.FMutex.Release;

    if LFound then
    begin
      LTask();
      LPool.FMutex.Acquire;
      LTask := nil;  // Release ref under mutex protection
      Dec(LPool.FPendingTasks);
      if LPool.FPendingTasks = 0 then
        LPool.FDoneCondVar.Broadcast;
      LPool.FMutex.Release;
    end
    else
    begin
      LPool.FMutex.Acquire;
      if LPool.FShutdown then
      begin
        LPool.FMutex.Release;
        Break;
      end;
      LPool.FCondVar.Wait(LPool.FMutex);
      LPool.FMutex.Release;
    end;
  end;
end;

constructor TWorkStealingPool.Create(const AWorkerCount: Integer);
var
  LI, LCount: Integer;
begin
  inherited Create;
  FShutdown := False;
  FPendingTasks := 0;
  FNextQueue := 0;

  if AWorkerCount > 0 then LCount := AWorkerCount
  else LCount := platform_cpu_count;
  if LCount > MAX_WORKERS then LCount := MAX_WORKERS;
  FWorkerCount := LCount;

  FMutex := nextpas.core.sync.mutex.TMutex.Create;
  FCondVar := nextpas.core.sync.condvar.TCondVar.Create;
  FDoneCondVar := nextpas.core.sync.condvar.TCondVar.Create;

  for LI := 0 to LCount - 1 do
  begin
    FQueues[LI].Head := 0;
    FQueues[LI].Tail := 0;
    FQueues[LI].Count := 0;
  end;

  for LI := 0 to LCount - 1 do
  begin
    FContexts[LI].Pool := Self;
    FContexts[LI].ID := LI;
    platform_thread_create(FWorkers[LI], @WorkerMain, @FContexts[LI]);
  end;
end;

destructor TWorkStealingPool.Destroy;
begin
  Shutdown;
  FDoneCondVar := nil;
  FCondVar := nil;
  FMutex := nil;
  inherited Destroy;
end;

procedure TWorkStealingPool.Submit(const ATask: TThreadTask);
var
  LQIdx: Integer;
begin
  FMutex.Acquire;
  if FShutdown then
  begin
    FMutex.Release;
    Exit;
  end;

  LQIdx := FNextQueue;
  FNextQueue := (FNextQueue + 1) mod FWorkerCount;

  if FQueues[LQIdx].Count < QUEUE_CAPACITY then
  begin
    FQueues[LQIdx].Tasks[FQueues[LQIdx].Tail] := ATask;
    FQueues[LQIdx].Tail := (FQueues[LQIdx].Tail + 1) mod QUEUE_CAPACITY;
    Inc(FQueues[LQIdx].Count);
    Inc(FPendingTasks);
  end
  else
  begin
    FCondVar.Broadcast;
    FMutex.Release;
    raise EInvalidOperation.Create('TWorkStealingPool.Submit: queue full');
  end;

  FCondVar.Broadcast;
  FMutex.Release;
end;

procedure TWorkStealingPool.Shutdown;
var
  LI: Integer;
  LRet: Pointer;
begin
  FMutex.Acquire;
  if FShutdown then
  begin
    FMutex.Release;
    Exit;
  end;
  FShutdown := True;
  FCondVar.Broadcast;
  FMutex.Release;

  for LI := 0 to FWorkerCount - 1 do
    platform_thread_join(FWorkers[LI], LRet);
end;

procedure TWorkStealingPool.WaitAll;
begin
  FMutex.Acquire;
  while FPendingTasks > 0 do
    FDoneCondVar.Wait(FMutex);
  FMutex.Release;
end;

function TWorkStealingPool.GetWorkerCount: Integer;
begin
  Result := FWorkerCount;
end;

function CreateWorkStealingPool(const AWorkerCount: Integer): IThreadPool;
begin
  Result := TWorkStealingPool.Create(AWorkerCount);
end;

end.
