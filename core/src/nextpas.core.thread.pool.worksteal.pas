unit nextpas.core.thread.pool.worksteal;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.base,
  nextpas.core.thread.intf;

{**
 * CreateWorkStealingPool - 创建 work-stealing 线程池
 *
 * @desc
 *   每个 worker 拥有独立的本地任务队列。Submit 将任务分配到
 *   负载最轻的 worker。空闲 worker 从其他 worker 的队列尾部偷取任务。
 *   相比单队列线程池，在高并发场景下减少锁竞争。
 *
 * @params
 *   AWorkerCount  工作线程数（0 = CPU 核心数）
 *}
function CreateWorkStealingPool(const AWorkerCount: Integer = 0): IThreadPool;

implementation

uses
  SysUtils,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.sync.condvar,
  nextpas.core.platform.thread,
  nextpas.core.atomic;

const
  QUEUE_CAPACITY = 4096;

type
  TWorkQueue = record
    Tasks: array[0..QUEUE_CAPACITY - 1] of TThreadTask;
    Head: Integer;
    Tail: Integer;
    Count: Integer;
    Mutex: IMutex;
  end;
  PWorkQueue = ^TWorkQueue;

  TWorkStealingPool = class(TInterfacedObject, IThreadPool)
  private
    FQueues: array of TWorkQueue;
    FWorkerCount: Integer;
    FWorkers: array of TPlatformThreadHandle;
    FShutdown: Boolean;
    FGlobalMutex: IMutex;
    FCondVar: ICondVar;
    FDoneCondVar: ICondVar;
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

type
  PWorkerContext = ^TWorkerContext;
  TWorkerContext = record
    Pool: TWorkStealingPool;
    WorkerID: Integer;
  end;

var
  GContexts: array[0..63] of TWorkerContext;

function TryDequeue(AQueue: PWorkQueue; out ATask: TThreadTask): Boolean;
begin
  Result := False;
  AQueue^.Mutex.Acquire;
  if AQueue^.Count > 0 then
  begin
    ATask := AQueue^.Tasks[AQueue^.Head];
    AQueue^.Tasks[AQueue^.Head] := nil;
    AQueue^.Head := (AQueue^.Head + 1) mod QUEUE_CAPACITY;
    Dec(AQueue^.Count);
    Result := True;
  end;
  AQueue^.Mutex.Release;
end;

function TrySteal(AQueue: PWorkQueue; out ATask: TThreadTask): Boolean;
begin
  Result := False;
  AQueue^.Mutex.Acquire;
  if AQueue^.Count > 0 then
  begin
    Dec(AQueue^.Count);
    ATask := AQueue^.Tasks[(AQueue^.Head + AQueue^.Count) mod QUEUE_CAPACITY];
    AQueue^.Tasks[(AQueue^.Head + AQueue^.Count) mod QUEUE_CAPACITY] := nil;
    Result := True;
  end;
  AQueue^.Mutex.Release;
end;

function WorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PWorkerContext;
  LPool: TWorkStealingPool;
  LMyID, LVictim, LI: Integer;
  LTask: TThreadTask;
  LGotWork: Boolean;
begin
  Result := nil;
  LCtx := PWorkerContext(AArg);
  LPool := LCtx^.Pool;
  LMyID := LCtx^.WorkerID;

  while True do
  begin
    LGotWork := False;

    // Try own queue first
    if TryDequeue(@LPool.FQueues[LMyID], LTask) then
      LGotWork := True
    else
    begin
      // Try stealing from others
      for LI := 1 to LPool.FWorkerCount - 1 do
      begin
        LVictim := (LMyID + LI) mod LPool.FWorkerCount;
        if TrySteal(@LPool.FQueues[LVictim], LTask) then
        begin
          LGotWork := True;
          Break;
        end;
      end;
    end;

    if LGotWork then
    begin
      try
        LTask();
      except
      end;
      LTask := nil;

      LPool.FGlobalMutex.Acquire;
      Dec(LPool.FPendingTasks);
      if LPool.FPendingTasks = 0 then
        LPool.FDoneCondVar.Broadcast;
      LPool.FGlobalMutex.Release;
    end
    else
    begin
      // No work — wait or exit
      LPool.FGlobalMutex.Acquire;
      if LPool.FShutdown then
      begin
        LPool.FGlobalMutex.Release;
        Break;
      end;
      LPool.FCondVar.Wait(LPool.FGlobalMutex);
      LPool.FGlobalMutex.Release;
    end;
  end;
end;

{ TWorkStealingPool }

constructor TWorkStealingPool.Create(const AWorkerCount: Integer);
var
  LI, LCount: Integer;
begin
  inherited Create;
  FShutdown := False;
  FPendingTasks := 0;
  FNextQueue := 0;

  if AWorkerCount > 0 then
    LCount := AWorkerCount
  else
    LCount := platform_cpu_count;
  if LCount > 64 then LCount := 64;

  FWorkerCount := LCount;
  SetLength(FQueues, LCount);
  SetLength(FWorkers, LCount);

  FGlobalMutex := nextpas.core.sync.mutex.TMutex.Create;
  FCondVar := nextpas.core.sync.condvar.TCondVar.Create;
  FDoneCondVar := nextpas.core.sync.condvar.TCondVar.Create;

  for LI := 0 to LCount - 1 do
  begin
    FQueues[LI].Head := 0;
    FQueues[LI].Tail := 0;
    FQueues[LI].Count := 0;
    FQueues[LI].Mutex := nextpas.core.sync.mutex.TMutex.Create;
  end;

  for LI := 0 to LCount - 1 do
  begin
    GContexts[LI].Pool := Self;
    GContexts[LI].WorkerID := LI;
    platform_thread_create(FWorkers[LI], @WorkerProc, @GContexts[LI]);
  end;
end;

destructor TWorkStealingPool.Destroy;
begin
  Shutdown;
  FDoneCondVar := nil;
  FCondVar := nil;
  FGlobalMutex := nil;
  inherited Destroy;
end;

procedure TWorkStealingPool.Submit(const ATask: TThreadTask);
var
  LQueueIdx: Integer;
  LQ: PWorkQueue;
begin
  FGlobalMutex.Acquire;
  if FShutdown then
  begin
    FGlobalMutex.Release;
    Exit;
  end;

  // Round-robin distribution
  LQueueIdx := FNextQueue mod FWorkerCount;
  FNextQueue := (FNextQueue + 1) mod FWorkerCount;
  Inc(FPendingTasks);
  FGlobalMutex.Release;

  LQ := @FQueues[LQueueIdx];
  LQ^.Mutex.Acquire;
  if LQ^.Count < QUEUE_CAPACITY then
  begin
    LQ^.Tasks[LQ^.Tail] := ATask;
    LQ^.Tail := (LQ^.Tail + 1) mod QUEUE_CAPACITY;
    Inc(LQ^.Count);
  end;
  LQ^.Mutex.Release;

  FCondVar.Broadcast;
end;

procedure TWorkStealingPool.Shutdown;
var
  LI: Integer;
  LRetVal: Pointer;
begin
  FGlobalMutex.Acquire;
  if FShutdown then
  begin
    FGlobalMutex.Release;
    Exit;
  end;
  FShutdown := True;
  FGlobalMutex.Release;

  FCondVar.Broadcast;

  for LI := 0 to FWorkerCount - 1 do
    platform_thread_join(FWorkers[LI], LRetVal);
end;

procedure TWorkStealingPool.WaitAll;
begin
  FGlobalMutex.Acquire;
  while FPendingTasks > 0 do
    FDoneCondVar.Wait(FGlobalMutex);
  FGlobalMutex.Release;
end;

function TWorkStealingPool.GetWorkerCount: Integer;
begin
  Result := FWorkerCount;
end;

{ Factory }

function CreateWorkStealingPool(const AWorkerCount: Integer): IThreadPool;
begin
  Result := TWorkStealingPool.Create(AWorkerCount);
end;

end.
