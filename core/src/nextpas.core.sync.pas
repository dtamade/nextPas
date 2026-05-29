unit nextpas.core.sync;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.base,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.sync.rwlock,
  nextpas.core.sync.waitgroup,
  nextpas.core.sync.condvar,
  nextpas.core.sync.once,
  nextpas.core.sync.spinlock,
  nextpas.core.sync.semaphore;

type
  TLockState = nextpas.core.sync.base.TLockState;
  ILockGuard = nextpas.core.sync.intf.ILockGuard;
  ILock = nextpas.core.sync.intf.ILock;
  IMutex = nextpas.core.sync.intf.IMutex;
  IRWLock = nextpas.core.sync.intf.IRWLock;
  IWaitGroup = nextpas.core.sync.intf.IWaitGroup;
  ICondVar = nextpas.core.sync.intf.ICondVar;
  IOnce = nextpas.core.sync.once.IOnce;
  ISpinLock = nextpas.core.sync.spinlock.ISpinLock;
  ISemaphore = nextpas.core.sync.semaphore.ISemaphore;

function Mutex: IMutex; inline;
function FutexMutex: IMutex; inline;
function RWLock: IRWLock; inline;
function WaitGroup: IWaitGroup; inline;
function CondVar: ICondVar; inline;
function Once: IOnce; inline;
function SpinLock: ISpinLock; inline;
function Semaphore(const AInitial: Int32 = 1): ISemaphore; inline;

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

function CondVar: ICondVar;
begin
  Result := nextpas.core.sync.condvar.TCondVar.Create;
end;

function Once: IOnce;
begin
  Result := nextpas.core.sync.once.CreateOnce;
end;

function SpinLock: ISpinLock;
begin
  Result := nextpas.core.sync.spinlock.CreateSpinLock;
end;

function Semaphore(const AInitial: Int32): ISemaphore;
begin
  Result := nextpas.core.sync.semaphore.CreateSemaphore(AInitial);
end;

end.
