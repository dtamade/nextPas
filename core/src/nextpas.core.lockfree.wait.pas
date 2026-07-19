unit nextpas.core.lockfree.wait;

{$I nextpas.core.settings.inc}

interface

const
  {** Default bounded timeout for lock-free wait operations (10ms).
      Prevents lost-wakeup deadlocks when FUTEX_WAKE(LIFO) starves
      a waiter whose expected epoch drifts far from the current value. }
  LOCKFREE_WAIT_TIMEOUT_NS = 10000000;

procedure LockFreeWaitData(AEpoch: PInt32; AWaiters: PInt32;
  const AExpectedEpoch: Int32; const ATimeoutNs: Int64);
procedure LockFreeWaitSpace(AEpoch: PInt32; AWaiters: PInt32;
  const AExpectedEpoch: Int32; const ATimeoutNs: Int64);
procedure LockFreeNotifyData(AEpoch: PInt32; AWaiters: PInt32);
procedure LockFreeNotifySpace(AEpoch: PInt32; AWaiters: PInt32);
procedure LockFreeWakeAll(AEpoch: PInt32);

implementation

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.platform.sync;

const
  SPIN_LIMIT = 32;

{ Preferred path: atomic_* + mo_* (Go/Rust parity style; H2-3 / Q1). }

procedure LockFreeNotifyData(AEpoch: PInt32; AWaiters: PInt32);
begin
  if (AEpoch = nil) or (AWaiters = nil) then
    Exit;
  atomic_fetch_add(AEpoch^, 1, mo_release);
  if atomic_load(AWaiters^, mo_relaxed) > 0 then
    platform_wake_address_all(AEpoch);
end;

procedure LockFreeNotifySpace(AEpoch: PInt32; AWaiters: PInt32);
begin
  if (AEpoch = nil) or (AWaiters = nil) then
    Exit;
  atomic_fetch_add(AEpoch^, 1, mo_release);
  if atomic_load(AWaiters^, mo_relaxed) > 0 then
    platform_wake_address_all(AEpoch);
end;

procedure LockFreeWaitEvent(AEpoch: PInt32; AWaiters: PInt32;
  const AExpectedEpoch: Int32; const ATimeoutNs: Int64); inline;
var
  LI: Int32;
begin
  if (AEpoch = nil) or (AWaiters = nil) then
    Exit;
  for LI := 0 to SPIN_LIMIT - 1 do
  begin
    if atomic_load(AEpoch^, mo_acquire) <> AExpectedEpoch then
      Exit;
    CpuPause;
  end;
  atomic_fetch_add(AWaiters^, 1, mo_acq_rel);
  try
    if atomic_load(AEpoch^, mo_acquire) = AExpectedEpoch then
      platform_wait_address32(AEpoch, AExpectedEpoch, ATimeoutNs);
  finally
    atomic_fetch_sub(AWaiters^, 1, mo_acq_rel);
  end;
end;

procedure LockFreeWaitData(AEpoch: PInt32; AWaiters: PInt32;
  const AExpectedEpoch: Int32; const ATimeoutNs: Int64);
begin
  LockFreeWaitEvent(AEpoch, AWaiters, AExpectedEpoch, ATimeoutNs);
end;

procedure LockFreeWaitSpace(AEpoch: PInt32; AWaiters: PInt32;
  const AExpectedEpoch: Int32; const ATimeoutNs: Int64);
begin
  LockFreeWaitEvent(AEpoch, AWaiters, AExpectedEpoch, ATimeoutNs);
end;

procedure LockFreeWakeAll(AEpoch: PInt32);
begin
  if AEpoch = nil then
    Exit;
  atomic_fetch_add(AEpoch^, 1, mo_release);
  platform_wake_address_all(AEpoch);
end;

end.
