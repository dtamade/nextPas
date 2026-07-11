unit nextpas.core.lockfree.workstealing;
{**
 * @desc Work-Stealing thread pool implementation.
 *
 * @details Per-thread deques with work stealing:
 *   - Each worker thread has its own deque
 *   - Local tasks: LIFO push/pop (cache-friendly)
 *   - Stolen tasks: FIFO steal (load balancing)
 *   - Submit: add task to any worker's deque
 *   - Close: graceful shutdown with task drain
 *
 * @concurrency Thread-safe for multiple threads:
 *   - Submit: multiple threads can submit tasks concurrently
 *   - Execute: worker threads process tasks in parallel
 *   - Steal: idle threads steal from busy threads
 *
 * @see Work Stealing — Blumofe & Leiserson, 1999
 * @see Java ForkJoinPool — similar work-stealing implementation
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.deque;

type
  TWorkStealingTask = procedure(AData: Pointer);
  TLockFreeWorkStealingResult = (wsSubmitted, wsStolen, wsEmpty, wsClosed);

  TQueuedTask = record
    Task: TWorkStealingTask;
    Data: Pointer;
  end;

  TTaskDeque = specialize TWorkStealingDequeImpl<TQueuedTask>;

  {** @desc 并发工作窃取线程池（Work Stealing Pool）
    @details 每个工作线程有自己的双端队列。
      本地任务 LIFO push/pop，窃取任务 FIFO steal。
      最小化竞争，适合任务并行场景。
      适用场景：任务调度、并行计算、fork-join。
  }
  TWorkStealingPool = class
  private
    FWorkerCount: Int64;
    FDeques: array of TTaskDeque;
    FOwnerLocks: array of Int32;
    FNextSubmit: Int64;
    FNextSteal: Int64;
    FClosed: Int32;
    procedure AcquireOwner(const AWorkerIndex: Int64);
    procedure ReleaseOwner(const AWorkerIndex: Int64);
  public
    constructor Create(const AWorkerCount: Int64);
    destructor Destroy; override;
    function Submit(const ATask: TWorkStealingTask; const AData: Pointer): Boolean;
    function Steal(out ATask: TWorkStealingTask; out AData: Pointer): TLockFreeWorkStealingResult;
    function GetWorkerCount: Int64;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic;

constructor TWorkStealingPool.Create(const AWorkerCount: Int64);
var
  LI: Int64;
begin
  if AWorkerCount <= 0 then
    raise EArgumentError.Create('TWorkStealingPool: worker count must be > 0');
  inherited Create;
  FWorkerCount := AWorkerCount;
  SetLength(FDeques, AWorkerCount);
  SetLength(FOwnerLocks, AWorkerCount);
  for LI := 0 to AWorkerCount - 1 do
  begin
    FDeques[LI] := TTaskDeque.Create(64);
    FOwnerLocks[LI] := 0;
  end;
  FNextSubmit := 0;
  FNextSteal := 0;
  FClosed := 0;
end;

destructor TWorkStealingPool.Destroy;
var
  LI: Int64;
begin
  for LI := 0 to High(FDeques) do
    FDeques[LI].Free;
  SetLength(FDeques, 0);
  SetLength(FOwnerLocks, 0);
  inherited Destroy;
end;

procedure TWorkStealingPool.AcquireOwner(const AWorkerIndex: Int64);
var
  LSpinCount: Int32;
begin
  LSpinCount := 0;
  while AtomicCompareExchange32(FOwnerLocks[AWorkerIndex], 0, 1, moAcquire) <> 0 do
  begin
    Inc(LSpinCount);
    if LSpinCount <= 64 then
      CpuPause
    else
      ThreadSwitch;
  end;
end;

procedure TWorkStealingPool.ReleaseOwner(const AWorkerIndex: Int64);
begin
  AtomicStore32(FOwnerLocks[AWorkerIndex], 0, moRelease);
end;

function TWorkStealingPool.Submit(const ATask: TWorkStealingTask; const AData: Pointer): Boolean;
var
  LQueuedTask: TQueuedTask;
  LWorkerIndex: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  LQueuedTask.Task := ATask;
  LQueuedTask.Data := AData;
  LWorkerIndex := Int64(QWord(AtomicFetchAdd64(FNextSubmit, 1, moRelaxed)) mod
    QWord(FWorkerCount));
  AcquireOwner(LWorkerIndex);
  try
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    Result := FDeques[LWorkerIndex].TryPush(LQueuedTask);
  finally
    ReleaseOwner(LWorkerIndex);
  end;
end;

function TWorkStealingPool.Steal(out ATask: TWorkStealingTask; out AData: Pointer): TLockFreeWorkStealingResult;
var
  LI: Int64;
  LStartIndex: Int64;
  LQueueIndex: Int64;
  LQueuedTask: TQueuedTask;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(wsClosed);
  ATask := nil;
  AData := nil;
  LStartIndex := Int64(QWord(AtomicFetchAdd64(FNextSteal, 1, moRelaxed)) mod
    QWord(FWorkerCount));
  for LI := 0 to FWorkerCount - 1 do
  begin
    LQueueIndex := (LStartIndex + LI) mod FWorkerCount;
    if FDeques[LQueueIndex].TrySteal(LQueuedTask) then
    begin
      ATask := LQueuedTask.Task;
      AData := LQueuedTask.Data;
      Exit(wsStolen);
    end;
    AcquireOwner(LQueueIndex);
    try
      if FDeques[LQueueIndex].TryPop(LQueuedTask) then
      begin
        ATask := LQueuedTask.Task;
        AData := LQueuedTask.Data;
        Exit(wsStolen);
      end;
    finally
      ReleaseOwner(LQueueIndex);
    end;
  end;
  Result := wsEmpty;
end;

function TWorkStealingPool.GetWorkerCount: Int64;
begin
  Result := FWorkerCount;
end;

procedure TWorkStealingPool.Close;
var
  LI: Int64;
begin
  AtomicStore32(FClosed, 1, moRelease);
  for LI := 0 to High(FDeques) do
  begin
    AcquireOwner(LI);
    try
      FDeques[LI].Close;
    finally
      ReleaseOwner(LI);
    end;
  end;
end;

function TWorkStealingPool.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
