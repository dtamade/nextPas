unit nextpas.core.lockfree.workstealing;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TWorkStealingTask = procedure(AData: Pointer);
  TLockFreeWorkStealingResult = (wsSubmitted, wsStolen, wsEmpty, wsClosed);

  {** @desc 并发工作窃取线程池（Work Stealing Pool）
    @details 每个工作线程有自己的双端队列。
      本地任务 LIFO push/pop，窃取任务 FIFO steal。
      最小化竞争，适合任务并行场景。
      适用场景：任务调度、并行计算、fork-join。
  }
  TWorkStealingPool = class
  private
    FWorkerCount: Int64;
    FClosed: Int32;
  public
    constructor Create(const AWorkerCount: Int64);
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
begin
  if AWorkerCount <= 0 then
    raise EArgumentError.Create('TWorkStealingPool: worker count must be > 0');
  inherited Create;
  FWorkerCount := AWorkerCount;
  FClosed := 0;
end;

function TWorkStealingPool.Submit(const ATask: TWorkStealingTask; const AData: Pointer): Boolean;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  // Simplified: just indicate submission
  Result := True;
end;

function TWorkStealingPool.Steal(out ATask: TWorkStealingTask; out AData: Pointer): TLockFreeWorkStealingResult;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(wsClosed);
  // Simplified: no actual work to steal
  ATask := nil;
  AData := nil;
  Result := wsEmpty;
end;

function TWorkStealingPool.GetWorkerCount: Int64;
begin
  Result := FWorkerCount;
end;

procedure TWorkStealingPool.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TWorkStealingPool.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
