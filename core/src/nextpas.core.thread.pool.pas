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
    FStartedWorkers: Integer;
    FActiveWorkers: Integer;
    FWorkers: array of TPlatformThreadHandle;
    FShutdown: Boolean;
    FPendingTasks: Integer;
    FNodePool: array[0..127] of TTaskNode;
    FNodePoolFree: Integer;
    function AllocNode: PTaskNode;
    procedure FreeNode(ANode: PTaskNode);
    procedure RunNode(ANode: PTaskNode);
    function TryPublishNode(ANode: PTaskNode): Boolean;
    { 惰性起线程：容量（FWorkerCount）与预创建解耦——首任务、已启动
      worker 全忙、或积压未被认领 ≥2 时补一条，直至容量。调用方持 FMutex。 }
    procedure StartWorkerLocked;
    { 出栈成功后置忙标记；任务完成时与 FPendingTasks 同锁递减并广播 Done }
    procedure BeginNode;
    procedure FinishNode(ANode: PTaskNode);
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

function WorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LPool: TThreadPool;
  LNodePtr: Pointer;
begin
  Result := nil;
  LPool := TThreadPool(AArg);

  while True do
  begin
    LNodePtr := nil;
    if LPool.FQueue.TryDequeue(LNodePtr) then
    begin
      LPool.BeginNode;
      LPool.RunNode(PTaskNode(LNodePtr));
      LPool.FinishNode(PTaskNode(LNodePtr));
      Continue;
    end;

    LPool.FMutex.Acquire;
    if LPool.FQueue.TryDequeue(LNodePtr) then
    begin
      Inc(LPool.FActiveWorkers);
      LPool.FMutex.Release;
      LPool.RunNode(PTaskNode(LNodePtr));
      LPool.FinishNode(PTaskNode(LNodePtr));
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

procedure TThreadPool.BeginNode;
begin
  FMutex.Acquire;
  Inc(FActiveWorkers);
  FMutex.Release;
end;

procedure TThreadPool.FinishNode(ANode: PTaskNode);
begin
  FMutex.Acquire;
  Dec(FPendingTasks);
  Dec(FActiveWorkers);
  if FPendingTasks = 0 then
    FDoneCondVar.Broadcast;
  FMutex.Release;
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
  { 惰性扩容（容量上界 FWorkerCount 不变），三触发全在锁内取一致快照：
    ① 首任务必起第一条——「零流量零线程」的起端；
    ② 已启动 worker 全部在执行中（BeginNode..FinishNode 窗口内）再补一条；
    ③ 积压逃生口：未被认领任务 ≥2——发布快于认领的突发提交里 worker
    还没来得及 BeginNode（快速路径计数锁外自增、短暂低估），仅靠 ②
    会永远停在 1 条；③ 保证突发按积压深度扩得出去。
    低估只影响扩容时机不影响正确性：队列中的任务由已启动或随后新起的
    worker 消费。 }
  if (FStartedWorkers < FWorkerCount) and
     ((FStartedWorkers = 0) or
      (FActiveWorkers >= FStartedWorkers) or
      (FPendingTasks - FActiveWorkers >= 2)) then
    StartWorkerLocked;
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

  { 容量语义保留：FWorkerCount = 上界（GetWorkerCount 契约不变）。
    线程按需启动（StartWorkerLocked）——空闲容量不再预创建 44×N 条
    futex 睡眠线程（pp888 双服务器实测 88 条闲置，见 proxy888
    wiki/feedback-core.md C-22）。}
  FWorkerCount := LCount;
end;

procedure TThreadPool.StartWorkerLocked;
var
  LIndex: Integer;
begin
  LIndex := FStartedWorkers;
  SetLength(FWorkers, LIndex + 1);
  platform_thread_create(FWorkers[LIndex], @WorkerProc, Self);
  Inc(FStartedWorkers);
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

  { 仅 join 实际启动过的 worker（惰性扩容：Length(FWorkers)=已启动数） }
  for LI := 0 to Length(FWorkers) - 1 do
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

function TThreadPool.GetStartedWorkerCount: Integer;
begin
  FMutex.Acquire;
  Result := FStartedWorkers;
  FMutex.Release;
end;

function CreateThreadPool(const AWorkerCount: Integer): IThreadPool;
begin
  Result := TThreadPool.Create(AWorkerCount);
end;

end.
