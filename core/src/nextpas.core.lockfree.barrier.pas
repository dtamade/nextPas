unit nextpas.core.lockfree.barrier;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TCyclicBarrierWaitResult = (bwArrived, bwClosed, bwTimeout, bwBroken);

  {** @desc 并发循环屏障（CyclicBarrier）
    @details N 个线程在屏障点同步，所有线程到达后一起继续。
      可重复使用：到达屏障后自动重置。
      适用于：分阶段并行计算、MapReduce 场景。
  }
  TCyclicBarrier = class
  private
    FParties: Int64;
    FCount: Int64;
    FGeneration: Int64;
    FClosed: Int32;
    function AwaitInternal(const ATimeoutNs: Int64): TCyclicBarrierWaitResult;
  public
    constructor Create(const AParties: Int64);
    function Await: TCyclicBarrierWaitResult;
    function AwaitTimeout(const ATimeoutNs: Int64): TCyclicBarrierWaitResult;
    function GetParties: Int64;
    function GetNumberWaiting: Int64;
    procedure Reset;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

constructor TCyclicBarrier.Create(const AParties: Int64);
begin
  if AParties <= 0 then
    raise EArgumentError.Create('TCyclicBarrier: parties must be > 0');
  inherited Create;
  FParties := AParties;
  FCount := AParties;
  FGeneration := 0;
  FClosed := 0;
end;

function TCyclicBarrier.AwaitInternal(const ATimeoutNs: Int64): TCyclicBarrierWaitResult;
var
  LGen: Int64;
  LOldCount: Int64;
  LStart: TInstant;
  LUseTimeout: Boolean;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(bwClosed);

  LUseTimeout := ATimeoutNs > 0;
  if LUseTimeout then
    LStart := TInstant.Now;

  LGen := AtomicLoad64(FGeneration, moAcquire);
  LOldCount := AtomicFetchSub64(FCount, 1, moAcqRel);
  if LOldCount = 1 then
  begin
    AtomicStore64(FCount, FParties, moRelease);
    AtomicFetchAdd64(FGeneration, 1, moRelease);
    Exit(bwArrived);
  end;

  while AtomicLoad64(FGeneration, moAcquire) = LGen do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
    begin
      AtomicStore64(FCount, FParties, moRelease);
      AtomicFetchAdd64(FGeneration, 1, moRelease);
      Exit(bwClosed);
    end;
    if LUseTimeout and (LStart.Elapsed.AsNanoseconds >= ATimeoutNs) then
    begin
      AtomicStore64(FCount, FParties, moRelease);
      AtomicFetchAdd64(FGeneration, 1, moRelease);
      Exit(bwTimeout);
    end;
    CpuPause;
  end;

  Result := bwArrived;
end;

function TCyclicBarrier.Await: TCyclicBarrierWaitResult;
begin
  Result := AwaitInternal(0);
end;

function TCyclicBarrier.AwaitTimeout(const ATimeoutNs: Int64): TCyclicBarrierWaitResult;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TCyclicBarrier.AwaitTimeout: timeout must be > 0');
  Result := AwaitInternal(ATimeoutNs);
end;

function TCyclicBarrier.GetParties: Int64;
begin
  Result := FParties;
end;

function TCyclicBarrier.GetNumberWaiting: Int64;
begin
  Result := FParties - AtomicLoad64(FCount, moAcquire);
end;

procedure TCyclicBarrier.Reset;
begin
  AtomicStore64(FCount, FParties, moRelaxed);
  AtomicFetchAdd64(FGeneration, 1, moRelease);
end;

procedure TCyclicBarrier.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
  AtomicStore64(FCount, FParties, moRelease);
  AtomicFetchAdd64(FGeneration, 1, moRelease);
end;

function TCyclicBarrier.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
