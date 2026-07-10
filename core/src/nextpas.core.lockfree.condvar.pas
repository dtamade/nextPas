unit nextpas.core.lockfree.condvar;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.mutex;

type
  TConditionVariableWaitResult = (cvSignaled, cvClosed, cvTimeout);

  {** @desc 并发条件变量（Condition Variable）
    @details 配合 TConcurrentMutex 使用，实现条件等待。
      Wait(AMutex) 原子释放锁并自旋等待，被唤醒后重新获取锁。
      Signal 唤醒一个等待者，Broadcast 唤醒所有等待者。
      适用于：生产者-消费者、条件同步。
  }
  TConditionVariable = class
  private
    FSignalCount: Int64;
    FBroadcastEpoch: Int64;
    FWaiters: Int32;
    FClosed: Int32;
  public
    constructor Create;

    {** @desc 释放 AMutex 并等待 Signal/Broadcast，唤醒后重新获取 AMutex }
    procedure Wait(AMutex: TConcurrentMutex);
    {** @desc 带超时的 Wait，返回 cvSignaled/cvClosed/cvTimeout }
    function WaitTimeout(AMutex: TConcurrentMutex; const ATimeoutNs: Int64): TConditionVariableWaitResult;

    {** @desc 唤醒一个等待者 }
    procedure Signal;
    {** @desc 唤醒所有等待者 }
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

const
  SIGNAL_ONE = 1;
  SIGNAL_ALL = MaxInt;

constructor TConditionVariable.Create;
begin
  inherited Create;
  FSignalCount := 0;
  FBroadcastEpoch := 0;
  FWaiters := 0;
  FClosed := 0;
end;

procedure TConditionVariable.Wait(AMutex: TConcurrentMutex);
var
  LBroadcastEpoch: Int64;
  LSignalCount: Int64;
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit;
  AtomicFetchAdd32(FWaiters, 1, moRelaxed);
  LBroadcastEpoch := AtomicLoad64(FBroadcastEpoch, moAcquire);
  AMutex.Unlock;
  try
    while True do
    begin
      if AtomicLoad32(FClosed, moAcquire) <> 0 then
        Break;
      if AtomicLoad64(FBroadcastEpoch, moAcquire) <> LBroadcastEpoch then
        Break;
      LSignalCount := AtomicLoad64(FSignalCount, moAcquire);
      if (LSignalCount > 0) and
         (AtomicCompareExchange64(FSignalCount, LSignalCount, LSignalCount - 1, moAcqRel) = LSignalCount) then
        Break;
      CpuPause;
    end;
  finally
    AtomicFetchSub32(FWaiters, 1, moRelaxed);
    AMutex.Lock;
  end;
end;

function TConditionVariable.WaitTimeout(AMutex: TConcurrentMutex;
  const ATimeoutNs: Int64): TConditionVariableWaitResult;
var
  LBroadcastEpoch: Int64;
  LSignalCount: Int64;
  LStart: TInstant;
begin
  if ATimeoutNs <= 0 then
    raise EArgumentError.Create('TConditionVariable.WaitTimeout: timeout must be > 0');
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(cvClosed);
  AtomicFetchAdd32(FWaiters, 1, moRelaxed);
  LBroadcastEpoch := AtomicLoad64(FBroadcastEpoch, moAcquire);
  LStart := TInstant.Now;
  AMutex.Unlock;
  try
    while True do
    begin
      if AtomicLoad32(FClosed, moAcquire) <> 0 then
        Exit(cvClosed);
      if AtomicLoad64(FBroadcastEpoch, moAcquire) <> LBroadcastEpoch then
        Exit(cvSignaled);
      LSignalCount := AtomicLoad64(FSignalCount, moAcquire);
      if (LSignalCount > 0) and
         (AtomicCompareExchange64(FSignalCount, LSignalCount, LSignalCount - 1, moAcqRel) = LSignalCount) then
        Exit(cvSignaled);
      if LStart.Elapsed.AsNanoseconds >= ATimeoutNs then
        Exit(cvTimeout);
      CpuPause;
    end;
  finally
    AtomicFetchSub32(FWaiters, 1, moRelaxed);
    AMutex.Lock;
  end;
end;

procedure TConditionVariable.Signal;
begin
  if AtomicLoad32(FWaiters, moAcquire) <= 0 then
    Exit;
  AtomicFetchAdd64(FSignalCount, SIGNAL_ONE, moRelease);
end;

procedure TConditionVariable.Broadcast;
begin
  if AtomicLoad32(FWaiters, moAcquire) <= 0 then
    Exit;
  AtomicFetchAdd64(FBroadcastEpoch, 1, moRelease);
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
