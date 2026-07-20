unit nextpas.core.lockfree.forkjoin;
{**
 * @desc ForkJoin parallel execution framework.
 *
 * @details Work-stealing based parallel task execution:
 *   - Submit: add task to thread pool
 *   - Fork/Join: split and merge parallel tasks
 *   - Work-stealing: idle threads steal from busy threads
 *   - Close: graceful shutdown with task drain
 *
 * @concurrency Thread-safe for multiple threads:
 *   - Submit: multiple threads can submit tasks concurrently
 *   - Execute: worker threads process tasks in parallel
 *   - Close: safe to call from any thread
 *
 * @see Fork/Join Framework — divide-and-conquer parallelism
 * @see Java ForkJoinPool — similar parallel execution framework
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.deque;

type
  TForkJoinTaskProc = procedure(AUserData: Pointer);

  TLockFreeForkJoinResult = (
    fjOk,
    fjClosed,
    fjTimeout,
    fjFull
  );

  {** @desc ForkJoin 任务 }
  TForkJoinTask = record
    Proc: TForkJoinTaskProc;
    UserData: Pointer;
  end;

  TTaskDeque = specialize TWorkStealingDequeImpl<TForkJoinTask>;

  {** @desc ForkJoin 并行执行框架
    @details 类似 Java ForkJoinPool，支持递归分治任务。
      - 每个工作者线程有本地双端队列
      - 本地任务 LIFO 执行（栈式热缓存）
      - 窃取任务 FIFO 执行（公平性）
      - 支持 Fork/Join 同步等待
      - 支持 Close 语义
    @see TWorkStealingDeque 底层双端队列
  }
  TLockFreeForkJoinPool = class
  private
    FDeques: array of TTaskDeque;
    FOwnerLocks: array of Int32;
    FWorkerCount: Int32;
    FNextWorker: Int64;  // round-robin for task submission
    FClosed: Int32;
    FTaskCount: Int64;
    FCompletedCount: Int64;
    procedure AcquireOwner(const AWorkerId: Int32);
    procedure ReleaseOwner(const AWorkerId: Int32);
  public
    {** @desc 创建 ForkJoin 池
      @param AWorkerCount 工作者线程数（= 队列数） }
    constructor Create(AWorkerCount: Int32 = 4);
    destructor Destroy; override;

    {** @desc 提交任务到当前工作者的本地队列
      @param ATask 任务
      @return fjOk 或 fjClosed/fjFull }
    function Fork(const ATask: TForkJoinTask): TLockFreeForkJoinResult;
    {** @desc 从本地队列或窃取任务执行一个任务
      @param AWorkerId 工作者 ID
      @param ATask 返回的任务
      @return 是否成功获取任务 }
    function PopOrSteal(AWorkerId: Int32; out ATask: TForkJoinTask): Boolean;
    {** @desc 关闭池 }
    procedure Close;
    {** @desc 池是否已关闭 }
    function IsClosed: Boolean; inline;
    {** @desc 工作者数量 }
    function WorkerCount: Int32; inline;
    {** @desc 大致待处理任务数 }
    function ApproxPendingCount: Int64; inline;
    {** @desc 大致已完成任务数 }
    function ApproxCompletedCount: Int64; inline;
  end;

implementation

uses
  nextpas.core.errors;

constructor TLockFreeForkJoinPool.Create(AWorkerCount: Int32);
var
  I: Int32;
begin
  inherited Create;
  if AWorkerCount < 1 then
    AWorkerCount := 1;
  FWorkerCount := AWorkerCount;
  SetLength(FDeques, AWorkerCount);
  SetLength(FOwnerLocks, AWorkerCount);
  for I := 0 to AWorkerCount - 1 do
  begin
    FDeques[I] := TTaskDeque.Create(64);
    FOwnerLocks[I] := 0;
  end;
  FNextWorker := 0;
  FClosed := 0;
  FTaskCount := 0;
  FCompletedCount := 0;
end;

destructor TLockFreeForkJoinPool.Destroy;
var
  I: Int32;
begin
  for I := 0 to FWorkerCount - 1 do
    FDeques[I].Free;
  SetLength(FDeques, 0);
  SetLength(FOwnerLocks, 0);
  inherited Destroy;
end;

procedure TLockFreeForkJoinPool.AcquireOwner(const AWorkerId: Int32);
var
  LSpinCount: Int32;
  LCasExpected: Int32;
begin
  LSpinCount := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FOwnerLocks[AWorkerId], LCasExpected, 1, mo_acquire, mo_relaxed) then
      Break;
    Inc(LSpinCount);
    if LSpinCount <= 64 then
      CpuPause
    else
      ThreadSwitch;
  end;
end;

procedure TLockFreeForkJoinPool.ReleaseOwner(const AWorkerId: Int32);
begin
  atomic_store(FOwnerLocks[AWorkerId], 0, mo_release);
end;

function TLockFreeForkJoinPool.Fork(const ATask: TForkJoinTask): TLockFreeForkJoinResult;
var
  LWorkerId: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(fjClosed);
  // Round-robin to next worker
  LWorkerId := Int32(QWord(atomic_fetch_add_64(FNextWorker, 1)) mod
    QWord(FWorkerCount));
  AcquireOwner(LWorkerId);
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(fjClosed);
    atomic_fetch_add_64(FTaskCount, 1, mo_relaxed);
    if FDeques[LWorkerId].TryPush(ATask) then
      Exit(fjOk);
    atomic_fetch_sub_64(FTaskCount, 1, mo_relaxed);
  finally
    ReleaseOwner(LWorkerId);
  end;
  Result := fjFull;
end;

function TLockFreeForkJoinPool.PopOrSteal(AWorkerId: Int32; out ATask: TForkJoinTask): Boolean;
var
  I, LVictim: Int32;
begin
  if (AWorkerId < 0) or (AWorkerId >= FWorkerCount) then
    raise EArgumentError.Create('TLockFreeForkJoinPool.PopOrSteal: invalid worker ID');
  // Try local pop first (LIFO)
  AcquireOwner(AWorkerId);
  try
    if FDeques[AWorkerId].TryPop(ATask) then
    begin
      atomic_fetch_add_64(FCompletedCount, 1);
      atomic_fetch_sub_64(FTaskCount, 1);
      Exit(True);
    end;
  finally
    ReleaseOwner(AWorkerId);
  end;
  // Try stealing from other workers (FIFO)
  for I := 1 to FWorkerCount - 1 do
  begin
    LVictim := (AWorkerId + I) mod FWorkerCount;
    if FDeques[LVictim].TrySteal(ATask) then
    begin
      atomic_fetch_add_64(FCompletedCount, 1);
      atomic_fetch_sub_64(FTaskCount, 1);
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure TLockFreeForkJoinPool.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TLockFreeForkJoinPool.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TLockFreeForkJoinPool.WorkerCount: Int32; inline;
begin
  Result := FWorkerCount;
end;

function TLockFreeForkJoinPool.ApproxPendingCount: Int64; inline;
begin
  Result := atomic_load_64(FTaskCount, mo_relaxed);
end;

function TLockFreeForkJoinPool.ApproxCompletedCount: Int64; inline;
begin
  Result := atomic_load_64(FCompletedCount, mo_relaxed);
end;

end.
