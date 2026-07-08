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

type
  PTaskNode = ^TTaskNode;
  TTaskNode = record
    Task: TThreadTask;
    DirectData: Pointer;
    DirectProc: TThreadProc;
    Next: PTaskNode;
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
    { Pre-allocated node pool }
    FNodePool: array[0..127] of TTaskNode;
    FNodePoolFree: Integer;
    function AllocNode: PTaskNode;
    procedure FreeNode(ANode: PTaskNode);
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

    { Snapshot task info, then clear the node before dispose.
      The anonymous task must be copied out before any field is nulled. }
    LDirectProc := LNode^.DirectProc;
    LDirectData := LNode^.DirectData;
    LTask := LNode^.Task;
    LNode^.Task := nil;
    LNode^.DirectProc := nil;
    LNode^.DirectData := nil;
    LNode^.Next := nil;
    if Assigned(LDirectProc) then
    begin
      LPool.FreeNode(LNode);
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
      LPool.FreeNode(LNode);
      LTask := nil;
    end;

    LPool.FMutex.Acquire;
    Dec(LPool.FPendingTasks);
    if LPool.FPendingTasks = 0 then
      LPool.FDoneCondVar.Broadcast
    else if LPool.FHead <> nil then
      LPool.FCondVar.Signal;
    LPool.FMutex.Release;
  end;
end;

{ TThreadPool — node pool }

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
  { Pool nodes are never freed — they live for the pool lifetime.
    Only heap-allocated fallback nodes are disposed. }
  if (PtrUInt(ANode) < PtrUInt(@FNodePool[0])) or
     (PtrUInt(ANode) >= PtrUInt(@FNodePool[128])) then
    Dispose(ANode);
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
  FNodePoolFree := 0;

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
  LNode^.Task := ATask;
  LNode^.DirectProc := nil;
  LNode^.DirectData := nil;
  LNode^.Next := nil;

  if FTail <> nil then
    FTail^.Next := LNode
  else
    FHead := LNode;
  FTail := LNode;
  Inc(FPendingTasks);

  FCondVar.Broadcast;
  FMutex.Release;
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
  LNode^.Task := TThreadTask(nil);  { unused for direct path }
  LNode^.DirectData := AData;
  LNode^.DirectProc := AProc;
  LNode^.Next := nil;

  if FTail <> nil then
    FTail^.Next := LNode
  else
    FHead := LNode;
  FTail := LNode;
  Inc(FPendingTasks);

  FCondVar.Broadcast;
  FMutex.Release;
end;

procedure TThreadPool.SubmitBatch(const ATasks: array of TThreadTask);
var
  LNode: PTaskNode;
  LCount, LI: Integer;
begin
  LCount := Length(ATasks);
  if LCount = 0 then
    Exit;

  FMutex.Acquire;

  if FShutdown then
  begin
    FMutex.Release;
    Exit;
  end;

  for LI := 0 to LCount - 1 do
  begin
    LNode := AllocNode;
    LNode^.Task := ATasks[LI];
    LNode^.DirectProc := nil;
    LNode^.DirectData := nil;
    LNode^.Next := nil;

    if FTail <> nil then
      FTail^.Next := LNode
    else
      FHead := LNode;
    FTail := LNode;
    Inc(FPendingTasks);
  end;

  { Single broadcast for the entire batch — workers claim tasks via the queue }
  FCondVar.Broadcast;
  FMutex.Release;
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

function TThreadPool.WaitAllTimeout(const ATimeoutNs: Int64): Boolean;
begin
  Result := True;
  FMutex.Acquire;
  while FPendingTasks > 0 do
  begin
    if not FDoneCondVar.WaitTimeout(FMutex, ATimeoutNs) then
    begin
      { Timed out — tasks still pending }
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
