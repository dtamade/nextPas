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
      Dispose(LNode);
      try
        LDirectProc(LDirectData);
      except
      end;
    end
    else
    begin
      try
        LTask();
      except
      end;
      Dispose(LNode);
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

  New(LNode);
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

  New(LNode);
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
