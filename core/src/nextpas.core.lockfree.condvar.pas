unit nextpas.core.lockfree.condvar;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TConditionVariableWaitResult = (cvSignaled, cvClosed, cvTimeout);

  {** @desc 并发条件变量（Condition Variable）
    @details 配合 TConcurrentMutex 使用，实现条件等待。
      Wait 释放锁并阻塞，被唤醒后重新获取锁。
      Signal 唤醒一个等待者，Broadcast 唤醒所有等待者。
      适用于：生产者-消费者、条件同步。
  }
  TConditionVariable = class
  private
    FSignalEpoch: Int64;
    FWaiters: Int32;
    FClosed: Int32;
  public
    constructor Create;
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): TConditionVariableWaitResult;
    procedure Signal;
    procedure Broadcast;
    procedure Close;
    function IsClosed: Boolean;
    function GetWaiterCount: Int32;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

constructor TConditionVariable.Create;
begin
  inherited Create;
  FSignalEpoch := 0;
  FWaiters := 0;
  FClosed := 0;
end;

procedure TConditionVariable.Wait;
var
  LOldEpoch: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit;
  AtomicFetchAdd32(FWaiters, 1, moRelaxed);
  LOldEpoch := AtomicLoad64(FSignalEpoch, moAcquire);
  while AtomicLoad64(FSignalEpoch, moAcquire) = LOldEpoch do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
    begin
      AtomicFetchSub32(FWaiters, 1, moRelaxed);
      Exit;
    end;
    CpuPause;
  end;
  AtomicFetchSub32(FWaiters, 1, moRelaxed);
end;

function TConditionVariable.WaitTimeout(const ATimeoutNs: Int64): TConditionVariableWaitResult;
var
  LOldEpoch: Int64;
  LStart: TInstant;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TConditionVariable.WaitTimeout: timeout must be > 0');
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(cvClosed);
  AtomicFetchAdd32(FWaiters, 1, moRelaxed);
  LOldEpoch := AtomicLoad64(FSignalEpoch, moAcquire);
  LStart := TInstant.Now;
  while AtomicLoad64(FSignalEpoch, moAcquire) = LOldEpoch do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
    begin
      AtomicFetchSub32(FWaiters, 1, moRelaxed);
      Exit(cvClosed);
    end;
    if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
    begin
      AtomicFetchSub32(FWaiters, 1, moRelaxed);
      Exit(cvTimeout);
    end;
    CpuPause;
  end;
  AtomicFetchSub32(FWaiters, 1, moRelaxed);
  Result := cvSignaled;
end;

procedure TConditionVariable.Signal;
begin
  AtomicFetchAdd64(FSignalEpoch, 1, moRelease);
end;

procedure TConditionVariable.Broadcast;
begin
  AtomicFetchAdd64(FSignalEpoch, 1, moRelease);
end;

procedure TConditionVariable.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConditionVariable.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TConditionVariable.GetWaiterCount: Int32;
begin
  Result := AtomicLoad32(FWaiters, moAcquire);
end;

end.
