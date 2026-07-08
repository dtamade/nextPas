unit nextpas.core.lockfree.forkjoin;

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
    FWorkerCount: Int32;
    FNextWorker: Int64;  // round-robin for task submission
    FClosed: Int32;
    FTaskCount: Int64;
    FCompletedCount: Int64;
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
    function IsClosed: Boolean;
    {** @desc 工作者数量 }
    function WorkerCount: Int32;
    {** @desc 大致待处理任务数 }
    function ApproxPendingCount: Int64;
    {** @desc 大致已完成任务数 }
    function ApproxCompletedCount: Int64;
  end;

implementation

constructor TLockFreeForkJoinPool.Create(AWorkerCount: Int32);
var
  I: Int32;
begin
  inherited Create;
  if AWorkerCount < 1 then
    AWorkerCount := 1;
  FWorkerCount := AWorkerCount;
  SetLength(FDeques, AWorkerCount);
  for I := 0 to AWorkerCount - 1 do
    FDeques[I] := TTaskDeque.Create(64);
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
  inherited Destroy;
end;

function TLockFreeForkJoinPool.Fork(const ATask: TForkJoinTask): TLockFreeForkJoinResult;
var
  LWorkerId: Int32;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(fjClosed);
  // Round-robin to next worker
  LWorkerId := Int32(AtomicFetchAdd64(FNextWorker, 1) mod FWorkerCount);
  if FDeques[LWorkerId].TryPush(ATask) then
  begin
    AtomicFetchAdd64(FTaskCount, 1);
    Exit(fjOk);
  end;
  Result := fjFull;
end;

function TLockFreeForkJoinPool.PopOrSteal(AWorkerId: Int32; out ATask: TForkJoinTask): Boolean;
var
  I, LVictim: Int32;
begin
  // Try local pop first (LIFO)
  if FDeques[AWorkerId].TryPop(ATask) then
  begin
    AtomicFetchAdd64(FCompletedCount, 1);
    AtomicFetchAdd64(FTaskCount, -1);
    Exit(True);
  end;
  // Try stealing from other workers (FIFO)
  for I := 1 to FWorkerCount - 1 do
  begin
    LVictim := (AWorkerId + I) mod FWorkerCount;
    if FDeques[LVictim].TrySteal(ATask) then
    begin
      AtomicFetchAdd64(FCompletedCount, 1);
      AtomicFetchAdd64(FTaskCount, -1);
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure TLockFreeForkJoinPool.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TLockFreeForkJoinPool.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TLockFreeForkJoinPool.WorkerCount: Int32;
begin
  Result := FWorkerCount;
end;

function TLockFreeForkJoinPool.ApproxPendingCount: Int64;
begin
  Result := AtomicLoad64(FTaskCount, moRelaxed);
end;

function TLockFreeForkJoinPool.ApproxCompletedCount: Int64;
begin
  Result := AtomicLoad64(FCompletedCount, moRelaxed);
end;

end.
