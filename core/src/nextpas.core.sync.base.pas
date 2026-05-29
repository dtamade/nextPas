unit nextpas.core.sync.base;

{$I nextpas.core.settings.inc}

interface

type
  TLockState = (
    lsUnlocked,
    lsLocked,
    lsLockedWithWaiters
  );

  TOnceProc = procedure;

  TBarrierWaitResult = record
    IsLeader: Boolean;
    Generation: Int64;
  end;

implementation

end.
