unit nextpas.core.lockfree.condvar;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base,
  nextpas.core.lockfree.mutex;

type
  TConditionVariableWaitResult = (cvSignaled, cvClosed, cvTimeout);

  PConditionWaiter = ^TConditionWaiter;
  TConditionWaiter = record
    Next: PConditionWaiter;
    Notified: Boolean;
  end;

  {** @desc 并发条件变量（Condition Variable）
    @details 配合 TConcurrentMutex 使用，实现条件等待。
      Wait(AMutex) 原子释放锁并自旋等待，被唤醒后重新获取锁。
      Signal 唤醒一个等待者，Broadcast 唤醒所有等待者。
      适用于：生产者-消费者、条件同步。
  }
  TConditionVariable = class
  private
    FStateLock: Int32;
    FWaiterHead: PConditionWaiter;
    FWaiters: Int32;
    FClosed: Int32;
    procedure AcquireState;
    procedure ReleaseState;
    procedure RemoveWaiter(AWaiter: PConditionWaiter);
    function WaitInternal(AMutex: TConcurrentMutex; const ATimeoutNs: Int64;
      const AUseTimeout: Boolean): TConditionVariableWaitResult;
  public
    constructor Create;
    destructor Destroy; override;

    {** @desc 释放 AMutex 并等待 Signal/Broadcast，唤醒后重新获取 AMutex }
    procedure Wait(AMutex: TConcurrentMutex);
    {** @desc 带超时的 Wait，返回 cvSignaled/cvClosed/cvTimeout }
    function WaitTimeout(AMutex: TConcurrentMutex; const ATimeoutNs: Int64): TConditionVariableWaitResult;

    {** @desc 唤醒一个等待者 }
    procedure Signal;
    {** @desc 唤醒所有等待者 }
    procedure Broadcast;

    procedure Close;
    function IsClosed: Boolean; inline;
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
  FStateLock := 0;
  FWaiterHead := nil;
  FWaiters := 0;
  FClosed := 0;
end;

procedure TConditionVariable.AcquireState;
var
  LSpinCount: Int32;
  LCasExpected: Int32;
begin
  LSpinCount := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FStateLock, LCasExpected, 1, mo_acquire, mo_relaxed) then
      Break;
    Inc(LSpinCount);
    if LSpinCount <= 64 then
      CpuPause
    else
      ThreadSwitch;
  end;
end;

procedure TConditionVariable.ReleaseState;
begin
  atomic_store(FStateLock, 0, mo_release);
end;

procedure TConditionVariable.RemoveWaiter(AWaiter: PConditionWaiter);
var
  LCurrent: PConditionWaiter;
  LPrevious: PConditionWaiter;
begin
  LCurrent := FWaiterHead;
  LPrevious := nil;
  while (LCurrent <> nil) and (LCurrent <> AWaiter) do
  begin
    LPrevious := LCurrent;
    LCurrent := LCurrent^.Next;
  end;
  if LCurrent = nil then
    Exit;
  if LPrevious = nil then
    FWaiterHead := LCurrent^.Next
  else
    LPrevious^.Next := LCurrent^.Next;
  LCurrent^.Next := nil;
  Dec(FWaiters);
end;

function TConditionVariable.WaitInternal(AMutex: TConcurrentMutex;
  const ATimeoutNs: Int64; const AUseTimeout: Boolean): TConditionVariableWaitResult;
var
  LWaiter: TConditionWaiter;
  LRegistered: Boolean;
  LMutexReleased: Boolean;
  LDone: Boolean;
  LSpinCount: Int32;
  LStart: TInstant;
begin
  if AMutex = nil then
    raise EArgumentError.Create('TConditionVariable.Wait: mutex must not be nil');
  if AUseTimeout and (ATimeoutNs <= 0) then
    raise EArgumentError.Create('TConditionVariable.WaitTimeout: timeout must be > 0');

  LRegistered := False;
  LMutexReleased := False;
  LWaiter.Next := nil;
  LWaiter.Notified := False;
  if AUseTimeout then
    LStart := TInstant.Now;
  AcquireState;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(cvClosed);
    if not AMutex.IsOwnedByCurrentThread then
      raise EInvalidOperationError.Create(
        'TConditionVariable.Wait: mutex must be owned by the current thread');
    if FWaiters = High(Int32) then
      raise EInvalidOperationError.Create('TConditionVariable: too many waiters');
    LWaiter.Next := FWaiterHead;
    FWaiterHead := @LWaiter;
    Inc(FWaiters);
    LRegistered := True;
  finally
    ReleaseState;
  end;

  try
    AMutex.Unlock;
    LMutexReleased := True;
    LSpinCount := 0;
    repeat
    begin
      LDone := False;
      AcquireState;
      try
        if atomic_load(FClosed, mo_acquire) <> 0 then
        begin
          Result := cvClosed;
          LDone := True;
        end
        else if LWaiter.Notified then
        begin
          Result := cvSignaled;
          LDone := True;
        end
        else if AUseTimeout and (LStart.Elapsed.AsNanoseconds >= ATimeoutNs) then
        begin
          Result := cvTimeout;
          LDone := True;
        end;
        if LDone then
        begin
          RemoveWaiter(@LWaiter);
          LRegistered := False;
        end;
      finally
        ReleaseState;
      end;
      if not LDone then
      begin
        Inc(LSpinCount);
        if LSpinCount <= 64 then
          CpuPause
        else
          ThreadSwitch;
      end;
    end
    until LDone;
  finally
    if LRegistered then
    begin
      AcquireState;
      try
        RemoveWaiter(@LWaiter);
      finally
        ReleaseState;
      end;
    end;
    if LMutexReleased then
      AMutex.Lock;
  end;
end;

procedure TConditionVariable.Wait(AMutex: TConcurrentMutex);
begin
  WaitInternal(AMutex, 0, False);
end;

function TConditionVariable.WaitTimeout(AMutex: TConcurrentMutex;
  const ATimeoutNs: Int64): TConditionVariableWaitResult;
begin
  Result := WaitInternal(AMutex, ATimeoutNs, True);
end;

procedure TConditionVariable.Signal;
var
  LWaiter: PConditionWaiter;
begin
  AcquireState;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit;
    LWaiter := FWaiterHead;
    while LWaiter <> nil do
    begin
      if not LWaiter^.Notified then
      begin
        LWaiter^.Notified := True;
        Exit;
      end;
      LWaiter := LWaiter^.Next;
    end;
  finally
    ReleaseState;
  end;
end;

procedure TConditionVariable.Broadcast;
var
  LWaiter: PConditionWaiter;
begin
  AcquireState;
  try
    if (atomic_load(FClosed, mo_acquire) <> 0) or (FWaiters <= 0) then
      Exit;
    LWaiter := FWaiterHead;
    while LWaiter <> nil do
    begin
      LWaiter^.Notified := True;
      LWaiter := LWaiter^.Next;
    end;
  finally
    ReleaseState;
  end;
end;

procedure TConditionVariable.Close;
begin
  AcquireState;
  try
    atomic_store(FClosed, 1, mo_release);
  finally
    ReleaseState;
  end;
end;

destructor TConditionVariable.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TConditionVariable.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TConditionVariable.GetWaiterCount: Int32;
begin
  AcquireState;
  try
    Result := FWaiters;
  finally
    ReleaseState;
  end;
end;

end.
