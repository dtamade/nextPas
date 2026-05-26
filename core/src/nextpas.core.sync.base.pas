unit nextpas.core.sync.base;

{$I nextpas.core.settings.inc}

interface

type
  TLockState = (
    lsUnlocked,
    lsLocked,
    lsLockedWithWaiters
  );

implementation

end.
