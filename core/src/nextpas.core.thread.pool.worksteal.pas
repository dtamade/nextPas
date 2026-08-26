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
 *   每个 worker 有独立 T1 work-stealing deque（unmanaged 任务槽间接层）。
 *   managed TThreadTask 不进入 deque 元素类型。
 *   跨平台（POSIX pthread / Windows threads via platform layer）。
 *
 * @progress 池整体为 work-stealing concurrent；deque 热路径为 lock-free
 *   （owner push/pop + multi-thief steal）。协调用 mutex/condvar（WaitAll/Shutdown）。
 *}
function CreateWorkStealingPool(const AWorkerCount: Integer = 0): IThreadPool;

implementation

uses
  nextpas.core.base,
  nextpas.core.atomic,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.sync.condvar,
  nextpas.core.platform.thread,
  nextpas.core.lockfree.deque;

const
  QUEUE_CAPACITY = 4096;
  MAX_WORKERS = 64;

type
  {** Heap node holds managed TThreadTask; deque only stores the pointer. }
  PTaskNode = ^TTaskNode;
  TTaskNode = record
    Task: TThreadTask;
  end;

  {** Unmanaged deque element: pointer to heap task node. }
  TDequeSlot = record
    Node: Pointer;
  end;

  TTaskDeque = specialize TWorkStealingDequeImpl<TDequeSlot>;

  TWorkStealingPool = class;

  PWorkerCtx = ^TWorkerCtx;
  TWorkerCtx = record
    Pool: TWorkStealingPool;
    ID: Integer;
  end;

  TWorkStealingPool = class(TInterfacedObject, IThreadPool)
  private
    FDeques: array of TTaskDeque;
    FOwnerLocks: array of Int32;
    FContexts: array[0..MAX_WORKERS - 1] of TWorkerCtx;
    FWorkerCount: Integer;
    FWorkers: array[0..MAX_WORKERS - 1] of TPlatformThreadHandle;
    FMutex: INativeMutex;
    FCondVar: ICondVar;
    FDoneCondVar: ICondVar;
    FShutdown: Boolean;
    FPendingTasks: Integer;
    FNextQueue: Integer;
    procedure AcquireOwner(const AWorkerIndex: Integer);
    procedure ReleaseOwner(const AWorkerIndex: Integer);
    function TryEnqueueSlot(const AWorkerIndex: Integer; const ASlot: TDequeSlot): Boolean;
    function TryTakeLocal(const AWorkerIndex: Integer; out ASlot: TDequeSlot): Boolean;
    function TryStealAny(const AThiefIndex: Integer; out ASlot: TDequeSlot): Boolean;
    procedure FreeTaskNode(var ANode: PTaskNode);
    procedure CloseDeques;
  public
    constructor Create(const AWorkerCount: Integer);
    destructor Destroy; override;
    procedure Submit(const ATask: TThreadTask);
    procedure SubmitDirect(AData: Pointer; AProc: TThreadProc);
    procedure SubmitBatch(const ATasks: array of TThreadTask);
    procedure SignalWorkers(const ACount: Integer);
    procedure Shutdown;
    procedure WaitAll;
    function WaitAllTimeout(const ATimeoutNs: Int64): Boolean;
    function GetWorkerCount: Integer;
    function GetStartedWorkerCount: Integer;
  end;

procedure TWorkStealingPool.AcquireOwner(const AWorkerIndex: Integer);
var
  LSpinCount: Int32;
  LExpected: Int32;
begin
  LSpinCount := 0;
  LExpected := 0;
  while not atomic_compare_exchange_strong(FOwnerLocks[AWorkerIndex], LExpected, 1, mo_acquire, mo_relaxed) do
  begin
    LExpected := 0;
    Inc(LSpinCount);
    if LSpinCount <= 64 then
      CpuPause
    else
      ThreadSwitch;
  end;
end;

procedure TWorkStealingPool.ReleaseOwner(const AWorkerIndex: Integer);
begin
  atomic_store(FOwnerLocks[AWorkerIndex], 0, mo_release);
end;

function TWorkStealingPool.TryEnqueueSlot(const AWorkerIndex: Integer;
  const ASlot: TDequeSlot): Boolean;
begin
  AcquireOwner(AWorkerIndex);
  try
    Result := FDeques[AWorkerIndex].TryPush(ASlot);
  finally
    ReleaseOwner(AWorkerIndex);
  end;
end;

function TWorkStealingPool.TryTakeLocal(const AWorkerIndex: Integer;
  out ASlot: TDequeSlot): Boolean;
begin
  AcquireOwner(AWorkerIndex);
  try
    Result := FDeques[AWorkerIndex].TryPop(ASlot);
  finally
    ReleaseOwner(AWorkerIndex);
  end;
end;

function TWorkStealingPool.TryStealAny(const AThiefIndex: Integer;
  out ASlot: TDequeSlot): Boolean;
var
  LI, LVictim: Integer;
begin
  Result := False;
  ASlot.Node := nil;
  for LI := 1 to FWorkerCount - 1 do
  begin
    LVictim := (AThiefIndex + LI) mod FWorkerCount;
    if FDeques[LVictim].TrySteal(ASlot) then
      Exit(True);
  end;
end;

procedure TWorkStealingPool.FreeTaskNode(var ANode: PTaskNode);
begin
  if ANode = nil then
    Exit;
  ANode^.Task := nil;
  Dispose(ANode);
  ANode := nil;
end;

procedure TWorkStealingPool.CloseDeques;
var
  LI: Integer;
begin
  for LI := 0 to FWorkerCount - 1 do
  begin
    AcquireOwner(LI);
    try
      FDeques[LI].Close;
    finally
      ReleaseOwner(LI);
    end;
  end;
end;

function WorkerMain(AArg: Pointer): Pointer; cdecl;
var
  LPool: TWorkStealingPool;
  LMyID: Integer;
  LSlot: TDequeSlot;
  LNode: PTaskNode;
  LTask: TThreadTask;
  LFound: Boolean;
begin
  Result := nil;
  LPool := PWorkerCtx(AArg)^.Pool;
  LMyID := PWorkerCtx(AArg)^.ID;

  while True do
  begin
    LFound := LPool.TryTakeLocal(LMyID, LSlot);
    if not LFound then
      LFound := LPool.TryStealAny(LMyID, LSlot);

    if LFound then
    begin
      LNode := PTaskNode(LSlot.Node);
      LTask := nil;
      if LNode <> nil then
      begin
        LTask := LNode^.Task;
        LPool.FreeTaskNode(LNode);
      end;
      if Assigned(LTask) then
        LTask();
      LTask := nil;

      LPool.FMutex.Acquire;
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
        if LPool.FPendingTasks = 0 then
        begin
          LPool.FMutex.Release;
          Break;
        end;
        { Drain race: tasks may still be in deques; release and retry without sleep. }
        LPool.FMutex.Release;
        Continue;
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

  if AWorkerCount > 0 then
    LCount := AWorkerCount
  else
    LCount := platform_cpu_count;
  if LCount > MAX_WORKERS then
    LCount := MAX_WORKERS;
  if LCount < 1 then
    LCount := 1;
  FWorkerCount := LCount;

  FMutex := nextpas.core.sync.mutex.TMutex.Create;
  FCondVar := nextpas.core.sync.condvar.TCondVar.Create;
  FDoneCondVar := nextpas.core.sync.condvar.TCondVar.Create;

  SetLength(FDeques, LCount);
  SetLength(FOwnerLocks, LCount);
  for LI := 0 to LCount - 1 do
  begin
    FDeques[LI] := TTaskDeque.Create(QUEUE_CAPACITY);
    FOwnerLocks[LI] := 0;
  end;

  for LI := 0 to LCount - 1 do
  begin
    FContexts[LI].Pool := Self;
    FContexts[LI].ID := LI;
    platform_thread_create(FWorkers[LI], @WorkerMain, @FContexts[LI]);
  end;
end;

destructor TWorkStealingPool.Destroy;
var
  LI: Integer;
begin
  Shutdown;
  for LI := 0 to High(FDeques) do
  begin
    FDeques[LI].Free;
    FDeques[LI] := nil;
  end;
  SetLength(FDeques, 0);
  SetLength(FOwnerLocks, 0);
  FDoneCondVar := nil;
  FCondVar := nil;
  FMutex := nil;
  inherited Destroy;
end;

procedure TWorkStealingPool.Submit(const ATask: TThreadTask);
var
  LQIdx: Integer;
  LNode: PTaskNode;
  LSlot: TDequeSlot;
begin
  if not Assigned(ATask) then
    Exit;

  New(LNode);
  LNode^.Task := ATask;
  LSlot.Node := LNode;

  FMutex.Acquire;
  if FShutdown then
  begin
    FMutex.Release;
    FreeTaskNode(LNode);
    Exit;
  end;

  LQIdx := FNextQueue;
  FNextQueue := (FNextQueue + 1) mod FWorkerCount;
  Inc(FPendingTasks);
  FMutex.Release;

  if not TryEnqueueSlot(LQIdx, LSlot) then
  begin
    FMutex.Acquire;
    Dec(FPendingTasks);
    if FPendingTasks = 0 then
      FDoneCondVar.Broadcast;
    FCondVar.Broadcast;
    FMutex.Release;
    FreeTaskNode(LNode);
    raise EInvalidOperation.Create('TWorkStealingPool.Submit: queue full');
  end;

  FMutex.Acquire;
  FCondVar.Broadcast;
  FMutex.Release;
end;

procedure TWorkStealingPool.SubmitDirect(AData: Pointer; AProc: TThreadProc);
begin
  { Fallback: wrap in a closure. Full zero-alloc optimization is in TThreadPool. }
  Submit(procedure
  begin
    AProc(AData);
  end);
end;

procedure TWorkStealingPool.SubmitBatch(const ATasks: array of TThreadTask);
var
  LCount, LI, LQIdx: Integer;
  LNode: PTaskNode;
  LSlot: TDequeSlot;
begin
  LCount := Length(ATasks);
  if LCount = 0 then
    Exit;

  for LI := 0 to LCount - 1 do
  begin
    if not Assigned(ATasks[LI]) then
      Continue;

    New(LNode);
    LNode^.Task := ATasks[LI];
    LSlot.Node := LNode;

    FMutex.Acquire;
    if FShutdown then
    begin
      FMutex.Release;
      FreeTaskNode(LNode);
      Exit;
    end;
    LQIdx := FNextQueue;
    FNextQueue := (FNextQueue + 1) mod FWorkerCount;
    Inc(FPendingTasks);
    FMutex.Release;

    if not TryEnqueueSlot(LQIdx, LSlot) then
    begin
      FMutex.Acquire;
      Dec(FPendingTasks);
      if FPendingTasks = 0 then
        FDoneCondVar.Broadcast;
      FCondVar.Broadcast;
      FMutex.Release;
      FreeTaskNode(LNode);
      raise EInvalidOperation.Create('TWorkStealingPool.SubmitBatch: queue full');
    end;
  end;

  FMutex.Acquire;
  FCondVar.Broadcast;
  FMutex.Release;
end;

procedure TWorkStealingPool.SignalWorkers(const ACount: Integer);
var
  I: Integer;
begin
  FMutex.Acquire;
  for I := 0 to ACount - 1 do
    FCondVar.Signal;
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
  FMutex.Release;

  CloseDeques;

  FMutex.Acquire;
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

function TWorkStealingPool.WaitAllTimeout(const ATimeoutNs: Int64): Boolean;
begin
  Result := True;
  FMutex.Acquire;
  while FPendingTasks > 0 do
  begin
    if not FDoneCondVar.WaitTimeout(FMutex, ATimeoutNs) then
    begin
      FMutex.Release;
      Exit(False);
    end;
  end;
  FMutex.Release;
end;

function TWorkStealingPool.GetStartedWorkerCount: Integer;
begin
  { 预创建语义：构造即满编，已启动数恒等于容量 }
  Result := FWorkerCount;
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
