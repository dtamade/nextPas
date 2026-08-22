unit nextpas.core.thread.pool;
{**
 * Default thread pool (non-worksteal).
 *
 * H4-1: task queue is T1 SegQueue of unmanaged PTaskNode pointers.
 * Multi-worker consumers require an MPMC-class queue (SegQueue), not MPSC.
 * Empty wait still uses mutex + condvar (no pure busy-spin).
 *}

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
  nextpas.core.lockfree.segqueue,
  nextpas.core.platform.thread;

type
  PTaskNode = ^TTaskNode;
  TTaskNode = record
    Task: TThreadTask;
    DirectData: Pointer;
    DirectProc: TThreadProc;
  end;

  TPointerSegQueue = specialize TSegQueueImpl<Pointer>;

  TThreadPool = class(TInterfacedObject, IThreadPool)
  private
    FMutex: INativeMutex;
    FCondVar: ICondVar;
    FDoneCondVar: ICondVar;
    FQueue: TPointerSegQueue;
    FWorkerCount: Integer;
    FWorkers: array of TPlatformThreadHandle;
    FShutdown: Boolean;
    FPendingTasks: Integer;
    FNodePool: array[0..127] of TTaskNode;
    FNodePoolFree: Integer;
    function AllocNode: PTaskNode;
    procedure FreeNode(ANode: PTaskNode);
    procedure RunNode(ANode: PTaskNode);
    function TryPublishNode(ANode: PTaskNode): Boolean;
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
  end;

function WorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LPool: TThreadPool;
  LNodePtr: Pointer;
  LNode: PTaskNode;
begin
  Result := nil;
  LPool := TThreadPool(AArg);

  while True do
  begin
    LNodePtr := nil;
    if LPool.FQueue.TryDequeue(LNodePtr) then
    begin
      LPool.RunNode(PTaskNode(LNodePtr));
      LPool.FMutex.Acquire;
      Dec(LPool.FPendingTasks);
      if LPool.FPendingTasks = 0 then
        LPool.FDoneCondVar.Broadcast;
      LPool.FMutex.Release;
      Continue;
    end;

    LPool.FMutex.Acquire;
    if LPool.FQueue.TryDequeue(LNodePtr) then
    begin
      LPool.FMutex.Release;
      LPool.RunNode(PTaskNode(LNodePtr));
      LPool.FMutex.Acquire;
      Dec(LPool.FPendingTasks);
      if LPool.FPendingTasks = 0 then
        LPool.FDoneCondVar.Broadcast;
      LPool.FMutex.Release;
      Continue;
    end;

    if LPool.FShutdown then
    begin
      LPool.FMutex.Release;
      Break;
    end;

    LPool.FCondVar.Wait(LPool.FMutex);
    LPool.FMutex.Release;
  end;
end;

procedure TThreadPool.RunNode(ANode: PTaskNode);
var
  LTask: TThreadTask;
  LDirectProc: TThreadProc;
  LDirectData: Pointer;
begin
  LDirectProc := ANode^.DirectProc;
  LDirectData := ANode^.DirectData;
  LTask := ANode^.Task;
  ANode^.Task := nil;
  ANode^.DirectProc := nil;
  ANode^.DirectData := nil;

  if Assigned(LDirectProc) then
  begin
    FreeNode(ANode);
    try
      LDirectProc(LDirectData);
    except
      on E: Exception do
        WriteLn(StdErr, '[ThreadPool] task raised: ', E.ClassName, ': ', E.Message);
    end;
  end
  else
  begin
    try
      LTask();
    except
      on E: Exception do
        WriteLn(StdErr, '[ThreadPool] task raised: ', E.ClassName, ': ', E.Message);
    end;
    FreeNode(ANode);
    LTask := nil;
  end;
end;

function TThreadPool.AllocNode: PTaskNode;
begin
  if FNodePoolFree < 128 then
  begin
    Result := @FNodePool[FNodePoolFree];
    Inc(FNodePoolFree);
  end
  else
    New(Result);
end;

procedure TThreadPool.FreeNode(ANode: PTaskNode);
begin
  if (PtrUInt(ANode) < PtrUInt(@FNodePool[0])) or
     (PtrUInt(ANode) >= PtrUInt(@FNodePool) + SizeOf(FNodePool)) then
    Dispose(ANode);
end;

function TThreadPool.TryPublishNode(ANode: PTaskNode): Boolean;
begin
  { Pending is incremented under mutex before enqueue so WaitAll cannot race. }
  FMutex.Acquire;
  if FShutdown then
  begin
    FMutex.Release;
    ANode^.Task := nil;
    ANode^.DirectProc := nil;
    ANode^.DirectData := nil;
    FreeNode(ANode);
    Exit(False);
  end;
  Inc(FPendingTasks);
  FMutex.Release;

  if not FQueue.TryEnqueue(Pointer(ANode)) then
  begin
    FMutex.Acquire;
    Dec(FPendingTasks);
    if FPendingTasks = 0 then
      FDoneCondVar.Broadcast;
    FMutex.Release;
    ANode^.Task := nil;
    ANode^.DirectProc := nil;
    ANode^.DirectData := nil;
    FreeNode(ANode);
    Exit(False);
  end;

  FMutex.Acquire;
  FCondVar.Broadcast;
  FMutex.Release;
  Result := True;
end;

constructor TThreadPool.Create(const AWorkerCount: Integer);
var
  LI: Integer;
  LCount: Integer;
begin
  inherited Create;
  FShutdown := False;
  FPendingTasks := 0;
  FNodePoolFree := 0;
  FQueue := TPointerSegQueue.Create;

  FMutex := nextpas.core.sync.mutex.TMutex.Create;
  FCondVar := nextpas.core.sync.condvar.TCondVar.Create;
  FDoneCondVar := nextpas.core.sync.condvar.TCondVar.Create;

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
  if FQueue <> nil then
  begin
    FQueue.Free;
    FQueue := nil;
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
  LNode := AllocNode;
  FMutex.Release;

  LNode^.Task := ATask;
  LNode^.DirectProc := nil;
  LNode^.DirectData := nil;
  TryPublishNode(LNode);
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
  LNode := AllocNode;
  FMutex.Release;

  LNode^.Task := TThreadTask(nil);
  LNode^.DirectData := AData;
  LNode^.DirectProc := AProc;
  TryPublishNode(LNode);
end;

procedure TThreadPool.SubmitBatch(const ATasks: array of TThreadTask);
var
  LNode: PTaskNode;
  LCount, LI: Integer;
begin
  LCount := Length(ATasks);
  if LCount = 0 then
    Exit;

  for LI := 0 to LCount - 1 do
  begin
    FMutex.Acquire;
    if FShutdown then
    begin
      FMutex.Release;
      Exit;
    end;
    LNode := AllocNode;
    FMutex.Release;

    LNode^.Task := ATasks[LI];
    LNode^.DirectProc := nil;
    LNode^.DirectData := nil;
    if not TryPublishNode(LNode) then
      Exit;
  end;
end;

procedure TThreadPool.SignalWorkers(const ACount: Integer);
var
  I: Integer;
begin
  FMutex.Acquire;
  for I := 0 to ACount - 1 do
    FCondVar.Signal;
  FMutex.Release;
end;

procedure TThreadPool.Shutdown;
var
  LI: Integer;
  LRetVal: Pointer;
  LNodePtr: Pointer;
  LNode: PTaskNode;
begin
  FMutex.Acquire;
  if FShutdown then
  begin
    FMutex.Release;
    Exit;
  end;
  FShutdown := True;
  FMutex.Release;

  if FQueue <> nil then
    FQueue.Close;

  FCondVar.Broadcast;

  for LI := 0 to FWorkerCount - 1 do
    platform_thread_join(FWorkers[LI], LRetVal);

  if FQueue <> nil then
    while FQueue.TryDequeue(LNodePtr) do
    begin
      LNode := PTaskNode(LNodePtr);
      LNode^.Task := nil;
      LNode^.DirectProc := nil;
      LNode^.DirectData := nil;
      FreeNode(LNode);
      FMutex.Acquire;
      if FPendingTasks > 0 then
        Dec(FPendingTasks);
      if FPendingTasks = 0 then
        FDoneCondVar.Broadcast;
      FMutex.Release;
    end;
end;

procedure TThreadPool.WaitAll;
begin
  FMutex.Acquire;
  while FPendingTasks > 0 do
    FDoneCondVar.Wait(FMutex);
  FMutex.Release;
end;

function TThreadPool.WaitAllTimeout(const ATimeoutNs: Int64): Boolean;
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

function TThreadPool.GetWorkerCount: Integer;
begin
  Result := FWorkerCount;
end;

function CreateThreadPool(const AWorkerCount: Integer): IThreadPool;
begin
  Result := TThreadPool.Create(AWorkerCount);
end;

end.
