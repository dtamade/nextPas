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

  { Scoped combinators and channel-adjacent callbacks. }
  TSyncProc = reference to procedure;

  TBarrierWaitResult = record
    IsLeader: Boolean;
    Generation: Int64;
  end;

  { Bounded MPMC channel of Pointer items (L1; no generics). }
  TChannelSendResult = (
    csrOk,
    csrClosed,
    csrFull
  );

  TChannelRecvResult = (
    crrOk,
    crrClosed,
    crrEmpty
  );

implementation

end.
