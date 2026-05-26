unit nextpas.core.sync;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.base,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.sync.rwlock,
  nextpas.core.sync.waitgroup;

type
  TLockState = nextpas.core.sync.base.TLockState;
  ILockGuard = nextpas.core.sync.intf.ILockGuard;
  ILock = nextpas.core.sync.intf.ILock;
  IMutex = nextpas.core.sync.intf.IMutex;
  IRWLock = nextpas.core.sync.intf.IRWLock;
  IWaitGroup = nextpas.core.sync.intf.IWaitGroup;
  TMutex = nextpas.core.sync.mutex.TMutex;
  TFutexMutex = nextpas.core.sync.mutex.TFutexMutex;
  TRWLock = nextpas.core.sync.rwlock.TRWLock;
  TWaitGroup = nextpas.core.sync.waitgroup.TWaitGroup;

function Mutex: IMutex; inline;
function FutexMutex: IMutex; inline;
function RWLock: IRWLock; inline;
function WaitGroup: IWaitGroup; inline;

implementation

function Mutex: IMutex;
begin
  Result := nextpas.core.sync.mutex.TMutex.Create;
end;

function FutexMutex: IMutex;
begin
  Result := nextpas.core.sync.mutex.TFutexMutex.Create;
end;

function RWLock: IRWLock;
begin
  Result := nextpas.core.sync.rwlock.TRWLock.Create;
end;

function WaitGroup: IWaitGroup;
begin
  Result := nextpas.core.sync.waitgroup.TWaitGroup.Create;
end;

end.
