unit nextpas.core.sync.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.base;

type
  ILockGuard = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560001}']
  end;

  ILock = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560002}']
    procedure Acquire;
    function TryAcquire: Boolean;
    procedure Release;
    function Lock: ILockGuard;
  end;

  IMutex = interface(ILock)
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560003}']
  end;

  IRWLock = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560004}']
    procedure AcquireRead;
    function TryAcquireRead: Boolean;
    procedure AcquireWrite;
    function TryAcquireWrite: Boolean;
    procedure ReleaseRead;
    procedure ReleaseWrite;
    function ReadLock: ILockGuard;
    function WriteLock: ILockGuard;
  end;

  IWaitGroup = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560005}']
    procedure Add(const ACount: Int32 = 1);
    procedure Done;
    procedure Wait;
  end;

  ICondVar = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560006}']
    procedure Wait(const AMutex: IMutex);
    function WaitTimeout(const AMutex: IMutex; const ATimeoutNs: Int64): Boolean;
    procedure Signal;
    procedure Broadcast;
  end;

  IOnce = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560010}']
    procedure Do_(const AProc: TOnceProc);
    function Done: Boolean;
  end;

  ISpinLock = interface(ILock)
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560011}']
  end;

  ISemaphore = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560012}']
    procedure Acquire;
    function TryAcquire: Boolean;
    function TryAcquireTimeout(const ATimeoutNs: Int64): Boolean;
    procedure Release;
    procedure Release(const ACount: Int32);
    function Available: Int32;
  end;

  IBarrier = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560013}']
    function Wait: TBarrierWaitResult;
  end;

  IEvent = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560014}']
    procedure SetEvent;
    procedure Reset;
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function IsSet: Boolean;
  end;

implementation

end.
