unit nextpas.core.sync.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.base,
  nextpas.core.time.base;

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

  { Application mutex — no native handle escape hatch. }
  IMutex = interface(ILock)
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560003}']
  end;

  { Platform-backed mutex: NativeHandle points at TPlatformMutex.
    Required partner for ICondVar.Wait / WaitTimeout. }
  INativeMutex = interface(IMutex)
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560015}']
    function NativeHandle: Pointer;
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
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function WaitTimeout(const ATimeout: TDuration): Boolean;
  end;

  ICondVar = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560006}']
    procedure Wait(const AMutex: INativeMutex);
    function WaitTimeout(const AMutex: INativeMutex; const ATimeoutNs: Int64): Boolean;
    function WaitTimeout(const AMutex: INativeMutex; const ATimeout: TDuration): Boolean;
    procedure Signal;
    procedure Broadcast;
  end;

  IOnce = interface
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560010}']
    procedure Do_(const AProc: TOnceProc);
    procedure DoOnce(const AProc: TOnceProc);
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
    function TryAcquireTimeout(const ATimeout: TDuration): Boolean;
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
    function WaitTimeout(const ATimeout: TDuration): Boolean;
    function IsSet: Boolean;
  end;

implementation

end.
