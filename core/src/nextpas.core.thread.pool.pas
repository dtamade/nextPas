unit nextpas.core.thread.pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.base,
  nextpas.core.thread.intf;

function CreateThreadPool(const AWorkerCount: Integer = 0): IThreadPool;

implementation

uses
  nextpas.core.errors,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.sync.condvar,
  nextpas.core.platform.thread;

const
  CNodePoolSize = 64;

type
  PTaskNode = ^TTaskNode;
  TTaskNode = record
    Task: TThreadTask;
    DirectData: Pointer;
    DirectProc: TThreadProc;
    Next: PTaskNode;
    PoolIndex: Integer;  { >=0: slot in pre-allocated pool; -1: heap-allocated }
  end;

  TThreadPool = class(TInterfacedObject, IThreadPool)
  private
    FMutex: IMutex;
    FCondVar: ICondVar;
    FDoneCondVar: ICondVar;
    FHead: PTaskNode;
    FTail: PTaskNode;
    FWorkerCount: Integer;
    FWorkers: array of TPlatformThreadHandle;
    FShutdown: Boolean;
    FPendingTasks: Integer;
    { Pre-allocated node pool: GetMem block that never moves }
    FPoolNodes: PTaskNode;     { pointer to array[0..CNodePoolSize-1] of TTaskNode }
    FPoolFreeCount: Integer;   { nodes [0..FPoolFreeCount-1] are available }
    function AcquireNode: PTaskNode;
    procedure ReturnNode(ANode: PTaskNode);
  public
    constructor Create(const AWorkerCount: Integer);
    destructor Destroy; override;
    procedure Submit(const ATask: TThreadTask);
    procedure SubmitDirect(AData: Pointer; AProc: TThreadProc);
    procedure Shutdown;
    procedure WaitAll;
    function GetWorkerCount: Integer;
  end;

function WorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LPool: TThreadPool;
  LNode: PTaskNode;
  LTask: TThreadTask;
  LDirectProc: TThreadProc;
  LDirectData: Pointer;
begin
  Result := nil;
  LPool := TThreadPool(AArg);

  while True do
  begin
    LPool.FMutex.Acquire;

    while (LPool.FHead = nil) and (not LPool.FShutdown) do
      LPool.FCondVar.Wait(LPool.FMutex);

    if (LPool.FHead = nil) and LPool.FShutdown then
    begin
      LPool.FMutex.Release;
      Break;
    end;

    LNode := LPool.FHead;
    LPool.FHead := LNode^.Next;
    if LPool.FHead = nil then
      LPool.FTail := nil;

    LPool.FMutex.Release;

    { Snapshot task info before returning node to pool }
    LDirectProc := LNode^.DirectProc;
    LDirectData := LNode^.DirectData;
    if Assigned(LDirectProc) then
    begin
      { Direct path: no refcounted closure. Clear and return node. }
      Pointer(LNode^.Task) := nil;
      LNode^.DirectProc := nil;
      LNode^.DirectData := nil;
      LPool.ReturnNode(LNode);
      try
        LDirectProc(LDirectData);
      except
      end;
    end
    else
    begin
      { Closure path: transfer ownership without triggering refcount (avoid race) }
      Pointer(LTask) := Pointer(LNode^.Task);
      Pointer(LNode^.Task) := nil;
      LNode^.DirectProc := nil;
      LNode^.DirectData := nil;
      LPool.ReturnNode(LNode);
      try
        LTask();
      except
      end;
      LTask := nil;
    end;

    LPool.FMutex.Acquire;
    Dec(LPool.FPendingTasks);
    if LPool.FPendingTasks = 0 then
      LPool.FDoneCondVar.Broadcast;
    LPool.FMutex.Release;
  end;
end;

{ TThreadPool }

function TThreadPool.AcquireNode: PTaskNode;
begin
  { Caller must hold FMutex }
  if FPoolFreeCount > 0 then
  begin
    Dec(FPoolFreeCount);
    Result := @FPoolNodes[FPoolFreeCount];
    Result^.PoolIndex := FPoolFreeCount;
  end
  else
  begin
    New(Result);
    Result^.PoolIndex := -1;
  end;
  Pointer(Result^.Task) := nil;
  Result^.DirectProc := nil;
  Result^.DirectData := nil;
  Result^.Next := nil;
end;

procedure TThreadPool.ReturnNode(ANode: PTaskNode);
begin
  { Called by worker after task execution, outside mutex }
  if ANode^.PoolIndex >= 0 then
  begin
    FMutex.Acquire;
    { Place back into pool: swap into free region }
    if FPoolFreeCount < CNodePoolSize then
    begin
      FPoolNodes[FPoolFreeCount] := ANode^;
      FPoolNodes[FPoolFreeCount].PoolIndex := FPoolFreeCount;
      FPoolNodes[FPoolFreeCount].Next := nil;
      Inc(FPoolFreeCount);
    end;
    FMutex.Release;
  end
  else
  begin
    { Heap-allocated node (pool was exhausted at submit time) }
    Pointer(ANode^.Task) := nil;
    Dispose(ANode);
  end;
end;

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

  FMutex := nextpas.core.sync.mutex.TMutex.Create;
  FCondVar := nextpas.core.sync.condvar.TCondVar.Create;
  FDoneCondVar := nextpas.core.sync.condvar.TCondVar.Create;

  if AWorkerCount > 0 then
    LCount := AWorkerCount
  else
    LCount := platform_cpu_count;

  FWorkerCount := LCount;
  SetLength(FWorkers, LCount);

  { Pre-allocate node pool: GetMem block, never moves, no refcount overhead }
  GetMem(FPoolNodes, CNodePoolSize * SizeOf(TTaskNode));
  FillChar(FPoolNodes^, CNodePoolSize * SizeOf(TTaskNode), 0);
  FPoolFreeCount := CNodePoolSize;

  for LI := 0 to LCount - 1 do
    platform_thread_create(FWorkers[LI], @WorkerProc, Self);
end;

destructor TThreadPool.Destroy;
begin
  Shutdown;
  if FPoolNodes <> nil then
  begin
    FreeMem(FPoolNodes);
    FPoolNodes := nil;
  end;
  FDoneCondVar := nil;
  FCondVar := nil;
  FMutex := nil;
  inherited Destroy;
end;

procedure TThreadPool.Submit(const ATask: TThreadTask);
var
  LNode: PTaskNode;
begin
  FMutex.Acquire;

  if FShutdown then
  begin
    FMutex.Release;
    Exit;
  end;

  LNode := AcquireNode;
  LNode^.Task := ATask;

  if FTail <> nil then
    FTail^.Next := LNode
  else
    FHead := LNode;
  FTail := LNode;
  Inc(FPendingTasks);

  FMutex.Release;
  FCondVar.Signal;
end;

procedure TThreadPool.SubmitDirect(AData: Pointer; AProc: TThreadProc);
var
  LNode: PTaskNode;
begin
  FMutex.Acquire;

  if FShutdown then
  begin
    FMutex.Release;
    Exit;
  end;

  LNode := AcquireNode;
  LNode^.DirectData := AData;
  LNode^.DirectProc := AProc;

  if FTail <> nil then
    FTail^.Next := LNode
  else
    FHead := LNode;
  FTail := LNode;
  Inc(FPendingTasks);

  FMutex.Release;
  FCondVar.Signal;
end;

procedure TThreadPool.Shutdown;
var
  LI: Integer;
  LRetVal: Pointer;
begin
  FMutex.Acquire;
  if FShutdown then
  begin
    FMutex.Release;
    Exit;
  end;
  FShutdown := True;
  FMutex.Release;

  FCondVar.Broadcast;

  for LI := 0 to FWorkerCount - 1 do
    platform_thread_join(FWorkers[LI], LRetVal);
end;

procedure TThreadPool.WaitAll;
begin
  FMutex.Acquire;
  while FPendingTasks > 0 do
    FDoneCondVar.Wait(FMutex);
  FMutex.Release;
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
