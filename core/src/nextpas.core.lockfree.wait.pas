unit nextpas.core.lockfree.wait;

{$I nextpas.core.settings.inc}

interface

procedure LockFreeWaitData(AEpoch: PInt32; AWaiters: PInt32;
  const ATimeoutNs: Int64);
procedure LockFreeWaitSpace(AEpoch: PInt32; AWaiters: PInt32;
  const ATimeoutNs: Int64);
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
  const ATimeoutNs: Int64);
var
  LEpoch: Int32;
  LI: Int32;
begin
  for LI := 0 to SPIN_LIMIT - 1 do
  begin
    LEpoch := AtomicLoad32(AEpoch^, moAcquire);
    if LEpoch <> AtomicLoad32(AEpoch^, moAcquire) then
      Exit;
    CpuPause;
  end;
  AtomicFetchAdd32(AWaiters^, 1, moAcqRel);
  LEpoch := AtomicLoad32(AEpoch^, moAcquire);
  platform_wait_address32(AEpoch, LEpoch, ATimeoutNs);
  AtomicFetchSub32(AWaiters^, 1, moAcqRel);
end;

procedure LockFreeWaitSpace(AEpoch: PInt32; AWaiters: PInt32;
  const ATimeoutNs: Int64);
var
  LEpoch: Int32;
  LI: Int32;
begin
  for LI := 0 to SPIN_LIMIT - 1 do
  begin
    LEpoch := AtomicLoad32(AEpoch^, moAcquire);
    if LEpoch <> AtomicLoad32(AEpoch^, moAcquire) then
      Exit;
    CpuPause;
  end;
  AtomicFetchAdd32(AWaiters^, 1, moAcqRel);
  LEpoch := AtomicLoad32(AEpoch^, moAcquire);
  platform_wait_address32(AEpoch, LEpoch, ATimeoutNs);
  AtomicFetchSub32(AWaiters^, 1, moAcqRel);
end;

procedure LockFreeWakeAll(AEpoch: PInt32);
begin
  AtomicFetchAdd32(AEpoch^, 1, moRelease);
  platform_wake_address_all(AEpoch);
end;

end.
