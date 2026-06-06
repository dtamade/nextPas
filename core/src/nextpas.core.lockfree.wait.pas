unit nextpas.core.lockfree.wait;

{$I nextpas.core.settings.inc}

interface

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
  nextpas.core.platform.sync;

const
  SPIN_LIMIT = 4;

procedure LockFreeNotifyData(AEpoch: PInt32; AWaiters: PInt32);
begin
  AtomicFetchAdd32(AEpoch^, 1, moRelease);
  if AtomicLoad32(AWaiters^, moRelaxed) > 0 then
    platform_wake_address_one(AEpoch);
end;

procedure LockFreeNotifySpace(AEpoch: PInt32; AWaiters: PInt32);
begin
  AtomicFetchAdd32(AEpoch^, 1, moRelease);
  if AtomicLoad32(AWaiters^, moRelaxed) > 0 then
    platform_wake_address_one(AEpoch);
end;

procedure LockFreeWaitData(AEpoch: PInt32; AWaiters: PInt32;
  const AExpectedEpoch: Int32; const ATimeoutNs: Int64);
var
  LI: Int32;
begin
  for LI := 0 to SPIN_LIMIT - 1 do
  begin
    if AtomicLoad32(AEpoch^, moAcquire) <> AExpectedEpoch then
      Exit;
    CpuPause;
  end;
  AtomicFetchAdd32(AWaiters^, 1, moAcqRel);
  try
    if AtomicLoad32(AEpoch^, moAcquire) = AExpectedEpoch then
      platform_wait_address32(AEpoch, AExpectedEpoch, ATimeoutNs);
  finally
    AtomicFetchSub32(AWaiters^, 1, moAcqRel);
  end;
end;

procedure LockFreeWaitSpace(AEpoch: PInt32; AWaiters: PInt32;
  const AExpectedEpoch: Int32; const ATimeoutNs: Int64);
var
  LI: Int32;
begin
  for LI := 0 to SPIN_LIMIT - 1 do
  begin
    if AtomicLoad32(AEpoch^, moAcquire) <> AExpectedEpoch then
      Exit;
    CpuPause;
  end;
  AtomicFetchAdd32(AWaiters^, 1, moAcqRel);
  try
    if AtomicLoad32(AEpoch^, moAcquire) = AExpectedEpoch then
      platform_wait_address32(AEpoch, AExpectedEpoch, ATimeoutNs);
  finally
    AtomicFetchSub32(AWaiters^, 1, moAcqRel);
  end;
end;

procedure LockFreeWakeAll(AEpoch: PInt32);
begin
  AtomicFetchAdd32(AEpoch^, 1, moRelease);
  platform_wake_address_all(AEpoch);
end;

end.
