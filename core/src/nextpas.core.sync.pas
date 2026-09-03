unit nextpas.core.sync;
{**
 * @desc 同步原语门面：Mutex、RWLock、SpinLock、WaitGroup、CondVar、Semaphore、
 *       Latch、Notify、Channel、Scoped 组合器与 TSyncPool（advanced）。
 *}

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
  nextpas.core.sync.semaphore,
  nextpas.core.sync.barrier,
  nextpas.core.sync.event,
  nextpas.core.sync.latch,
  nextpas.core.sync.notify,
  nextpas.core.sync.channel,
  nextpas.core.sync.scoped,
  nextpas.core.sync.pool,
  nextpas.core.sync.cow;

type
  TLockState = nextpas.core.sync.base.TLockState;
  TOnceProc = nextpas.core.sync.base.TOnceProc;
  TSyncProc = nextpas.core.sync.base.TSyncProc;
  TBarrierWaitResult = nextpas.core.sync.base.TBarrierWaitResult;
  TChannelSendResult = nextpas.core.sync.base.TChannelSendResult;
  TChannelRecvResult = nextpas.core.sync.base.TChannelRecvResult;

  ILockGuard = nextpas.core.sync.intf.ILockGuard;
  ILock = nextpas.core.sync.intf.ILock;
  IMutex = nextpas.core.sync.intf.IMutex;
  INativeMutex = nextpas.core.sync.intf.INativeMutex;
  IRWLock = nextpas.core.sync.intf.IRWLock;
  IWaitGroup = nextpas.core.sync.intf.IWaitGroup;
  ICondVar = nextpas.core.sync.intf.ICondVar;
  IOnce = nextpas.core.sync.intf.IOnce;
  ISpinLock = nextpas.core.sync.intf.ISpinLock;
  ISemaphore = nextpas.core.sync.intf.ISemaphore;
  IBarrier = nextpas.core.sync.intf.IBarrier;
  IEvent = nextpas.core.sync.intf.IEvent;
  ILatch = nextpas.core.sync.intf.ILatch;
  INotify = nextpas.core.sync.intf.INotify;
  IChannel = nextpas.core.sync.intf.IChannel;

  TPoolFactory = nextpas.core.sync.pool.TPoolFactory;
  TPoolDestroy = nextpas.core.sync.pool.TPoolDestroy;
  TPoolItem = nextpas.core.sync.pool.TPoolItem;
  TSyncPoolConfig = nextpas.core.sync.pool.TSyncPoolConfig;
  TSyncPool = nextpas.core.sync.pool.TSyncPool;
  TSyncPoolBuilder = nextpas.core.sync.pool.TSyncPoolBuilder;

function Mutex: INativeMutex; inline;
function RecursiveMutex: INativeMutex; inline;
function FutexMutex: IMutex; inline;
function RWLock: IRWLock; inline;
function WaitGroup: IWaitGroup; inline;
function CondVar: ICondVar; inline;
function Once: IOnce; inline;
function SpinLock: ISpinLock; inline;
function Semaphore(const AInitial: Int32 = 1): ISemaphore; inline;
function Barrier(const ACount: Int32): IBarrier; inline;
function Event(const AManualReset: Boolean = True): IEvent; inline;
function Latch(const ACount: Int32): ILatch; inline;
function Notify: INotify; inline;
function Channel(const ACapacity: SizeInt): IChannel; inline;

procedure WithLock(const ALock: ILock; const AProc: TSyncProc); inline;
procedure WithReadLock(const ARW: IRWLock; const AProc: TSyncProc); inline;
procedure WithWriteLock(const ARW: IRWLock; const AProc: TSyncProc); inline;
function Guard(const ALock: ILock): ILockGuard; inline;
function ReadGuard(const ARW: IRWLock): ILockGuard; inline;
function WriteGuard(const ARW: IRWLock): ILockGuard; inline;

function CreateSyncPool(AFactory: TPoolFactory): TSyncPool; inline;

implementation

function Mutex: INativeMutex;
begin
  Result := nextpas.core.sync.mutex.TMutex.Create;
end;

function RecursiveMutex: INativeMutex;
begin
  Result := nextpas.core.sync.mutex.TRecursiveMutex.Create;
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

function Barrier(const ACount: Int32): IBarrier;
begin
  Result := nextpas.core.sync.barrier.CreateBarrier(ACount);
end;

function Event(const AManualReset: Boolean): IEvent;
begin
  Result := nextpas.core.sync.event.CreateEvent(AManualReset);
end;

function Latch(const ACount: Int32): ILatch;
begin
  Result := nextpas.core.sync.latch.CreateLatch(ACount);
end;

function Notify: INotify;
begin
  Result := nextpas.core.sync.notify.CreateNotify;
end;

function Channel(const ACapacity: SizeInt): IChannel;
begin
  Result := nextpas.core.sync.channel.CreateChannel(ACapacity);
end;

procedure WithLock(const ALock: ILock; const AProc: TSyncProc);
begin
  nextpas.core.sync.scoped.WithLock(ALock, AProc);
end;

procedure WithReadLock(const ARW: IRWLock; const AProc: TSyncProc);
begin
  nextpas.core.sync.scoped.WithReadLock(ARW, AProc);
end;

procedure WithWriteLock(const ARW: IRWLock; const AProc: TSyncProc);
begin
  nextpas.core.sync.scoped.WithWriteLock(ARW, AProc);
end;

function Guard(const ALock: ILock): ILockGuard;
begin
  Result := nextpas.core.sync.scoped.Guard(ALock);
end;

function ReadGuard(const ARW: IRWLock): ILockGuard;
begin
  Result := nextpas.core.sync.scoped.ReadGuard(ARW);
end;

function WriteGuard(const ARW: IRWLock): ILockGuard;
begin
  Result := nextpas.core.sync.scoped.WriteGuard(ARW);
end;

function CreateSyncPool(AFactory: TPoolFactory): TSyncPool;
begin
  Result := nextpas.core.sync.pool.CreateSyncPool(AFactory);
end;

end.
