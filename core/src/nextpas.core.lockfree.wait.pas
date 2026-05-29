unit nextpas.core.lockfree.wait;

{$I nextpas.core.settings.inc}

interface

procedure LockFreeWaitData(AEpoch: PInt32; const AExpected: Int32;
  const ATimeoutNs: Int64);
procedure LockFreeWakeData(AEpoch: PInt32);
procedure LockFreeNotifyData(AEpoch: PInt32);
procedure LockFreeWaitSpace(AEpoch: PInt32; const AExpected: Int32;
  const ATimeoutNs: Int64);
procedure LockFreeWakeSpace(AEpoch: PInt32);
procedure LockFreeNotifySpace(AEpoch: PInt32);

implementation

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.platform.sync,
  nextpas.core.platform.thread;

procedure SpinThenWait(AAddr: PInt32; const AExpected: Int32;
  const ATimeoutNs: Int64);
var
  LI: Int32;
begin
  for LI := 0 to LOCKFREE_SPIN_COUNT - 1 do
  begin
    if AtomicLoad32(AAddr^, moAcquire) <> AExpected then
      Exit;
    CpuPause;
  end;
  for LI := 0 to LOCKFREE_YIELD_COUNT - 1 do
  begin
    if AtomicLoad32(AAddr^, moAcquire) <> AExpected then
      Exit;
    platform_thread_yield;
  end;
  if AtomicLoad32(AAddr^, moAcquire) = AExpected then
    platform_wait_address32(AAddr, AExpected, ATimeoutNs);
end;

procedure LockFreeWaitData(AEpoch: PInt32; const AExpected: Int32;
  const ATimeoutNs: Int64);
begin
  SpinThenWait(AEpoch, AExpected, ATimeoutNs);
end;

procedure LockFreeWakeData(AEpoch: PInt32);
begin
  AtomicFetchAdd32(AEpoch^, 1, moRelease);
  platform_wake_address_all(AEpoch);
end;

procedure LockFreeNotifyData(AEpoch: PInt32);
begin
  AtomicFetchAdd32(AEpoch^, 1, moRelease);
end;

procedure LockFreeWaitSpace(AEpoch: PInt32; const AExpected: Int32;
  const ATimeoutNs: Int64);
begin
  SpinThenWait(AEpoch, AExpected, ATimeoutNs);
end;

procedure LockFreeWakeSpace(AEpoch: PInt32);
begin
  AtomicFetchAdd32(AEpoch^, 1, moRelease);
  platform_wake_address_all(AEpoch);
end;

procedure LockFreeNotifySpace(AEpoch: PInt32);
begin
  AtomicFetchAdd32(AEpoch^, 1, moRelease);
end;

end.
