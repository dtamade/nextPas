unit nextpas.core.lockfree.workstealing;

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
    FNextSubmit: Int64;
    FNextSteal: Int64;
    FClosed: Int32;
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
  for LI := 0 to AWorkerCount - 1 do
    FDeques[LI] := TTaskDeque.Create(64);
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
  inherited Destroy;
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
  LWorkerIndex := AtomicFetchAdd64(FNextSubmit, 1, moRelaxed) mod FWorkerCount;
  Result := FDeques[LWorkerIndex].TryPush(LQueuedTask);
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
  LStartIndex := AtomicFetchAdd64(FNextSteal, 1, moRelaxed) mod FWorkerCount;
  for LI := 0 to FWorkerCount - 1 do
  begin
    LQueueIndex := (LStartIndex + LI) mod FWorkerCount;
    if FDeques[LQueueIndex].TrySteal(LQueuedTask) or FDeques[LQueueIndex].TryPop(LQueuedTask) then
    begin
      ATask := LQueuedTask.Task;
      AData := LQueuedTask.Data;
      Exit(wsStolen);
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
    FDeques[LI].Close;
end;

function TWorkStealingPool.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
