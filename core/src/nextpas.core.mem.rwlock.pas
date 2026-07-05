unit nextpas.core.mem.rwlock;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.sync;

type
  {** TMemRwLock — 平台读写锁 record 封装
   *
   *  @note 平台默认策略：
   *    Linux (pthread_rwlock): write-preferring (PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP)
   *    macOS (pthread_rwlock): write-preferring (默认)
   *    Windows (SRWLock): 未文档化，实测 write-preferring
   *    与 Rust parking_lot::RwLock (write-preferring) 和 Go sync.RWMutex (write-preferring) 一致。
   *
   *  @warning 不可拷贝/传值 — 与 TMemMutex 相同约束，多线程共享时必须通过指针传递。
   *}
  TMemRwLock = record
  private
    FHandle: TPlatformRwLock;
    FState: LongInt;
  public
    procedure Init;
    procedure Done;
    procedure AcquireRead;
    procedure ReleaseRead;
    procedure AcquireWrite;
    procedure ReleaseWrite;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.platform.thread;

const
  MEM_RWLOCK_STATE_UNINITIALIZED = 0;
  MEM_RWLOCK_STATE_INITIALIZING = 1;
  MEM_RWLOCK_STATE_INITIALIZED = 2;
  MEM_RWLOCK_STATE_DESTROYING = 3;

procedure RaiseRwLockError(const AOperation: string; const AError: Int32); inline;
begin
  raise ENextPasError.CreateFmt('TMemRwLock.%s failed: %d', [AOperation, AError]);
end;

procedure TMemRwLock.Init;
var
  LState: LongInt;
  LResult: Int32;
begin
  while True do
  begin
    LState := InterlockedCompareExchange(FState,
      MEM_RWLOCK_STATE_UNINITIALIZED,
      MEM_RWLOCK_STATE_UNINITIALIZED);
    case LState of
      MEM_RWLOCK_STATE_UNINITIALIZED:
        begin
          if InterlockedCompareExchange(FState,
            MEM_RWLOCK_STATE_INITIALIZING,
            MEM_RWLOCK_STATE_UNINITIALIZED) <> MEM_RWLOCK_STATE_UNINITIALIZED then
            Continue;
          ZeroMem(@FHandle, SizeOf(FHandle));
          LResult := platform_rwlock_init(FHandle);
          if LResult <> 0 then
          begin
            ZeroMem(@FHandle, SizeOf(FHandle));
            InterlockedExchange(FState, MEM_RWLOCK_STATE_UNINITIALIZED);
            RaiseRwLockError('Init', LResult);
          end;
          InterlockedExchange(FState, MEM_RWLOCK_STATE_INITIALIZED);
          Exit;
        end;
      MEM_RWLOCK_STATE_INITIALIZED:
        Exit;
    else
      platform_thread_yield;
    end;
  end;
end;

procedure TMemRwLock.Done;
var
  LState: LongInt;
  LResult: Int32;
begin
  while True do
  begin
    LState := InterlockedCompareExchange(FState,
      MEM_RWLOCK_STATE_UNINITIALIZED,
      MEM_RWLOCK_STATE_UNINITIALIZED);
    case LState of
      MEM_RWLOCK_STATE_UNINITIALIZED:
        Exit;
      MEM_RWLOCK_STATE_INITIALIZED:
        begin
          if InterlockedCompareExchange(FState,
            MEM_RWLOCK_STATE_DESTROYING,
            MEM_RWLOCK_STATE_INITIALIZED) <> MEM_RWLOCK_STATE_INITIALIZED then
            Continue;
          LResult := platform_rwlock_destroy(FHandle);
          if LResult <> 0 then
          begin
            InterlockedExchange(FState, MEM_RWLOCK_STATE_INITIALIZED);
            RaiseRwLockError('Done', LResult);
          end;
          ZeroMem(@FHandle, SizeOf(FHandle));
          InterlockedExchange(FState, MEM_RWLOCK_STATE_UNINITIALIZED);
          Exit;
        end;
    else
      platform_thread_yield;
    end;
  end;
end;

procedure TMemRwLock.AcquireRead;
var
  LResult: Int32;
begin
  if InterlockedCompareExchange(FState,
    MEM_RWLOCK_STATE_UNINITIALIZED,
    MEM_RWLOCK_STATE_UNINITIALIZED) <> MEM_RWLOCK_STATE_INITIALIZED then
    RaiseRwLockError('AcquireRead', PLATFORM_ERR_INVALID);
  LResult := platform_rwlock_rdlock(FHandle);
  if LResult <> 0 then
    RaiseRwLockError('AcquireRead', LResult);
end;

procedure TMemRwLock.ReleaseRead;
var
  LResult: Int32;
begin
  if InterlockedCompareExchange(FState,
    MEM_RWLOCK_STATE_UNINITIALIZED,
    MEM_RWLOCK_STATE_UNINITIALIZED) <> MEM_RWLOCK_STATE_INITIALIZED then
    RaiseRwLockError('ReleaseRead', PLATFORM_ERR_INVALID);
  LResult := platform_rwlock_rdunlock(FHandle);
  if LResult <> 0 then
    RaiseRwLockError('ReleaseRead', LResult);
end;

procedure TMemRwLock.AcquireWrite;
var
  LResult: Int32;
begin
  if InterlockedCompareExchange(FState,
    MEM_RWLOCK_STATE_UNINITIALIZED,
    MEM_RWLOCK_STATE_UNINITIALIZED) <> MEM_RWLOCK_STATE_INITIALIZED then
    RaiseRwLockError('AcquireWrite', PLATFORM_ERR_INVALID);
  LResult := platform_rwlock_wrlock(FHandle);
  if LResult <> 0 then
    RaiseRwLockError('AcquireWrite', LResult);
end;

procedure TMemRwLock.ReleaseWrite;
var
  LResult: Int32;
begin
  if InterlockedCompareExchange(FState,
    MEM_RWLOCK_STATE_UNINITIALIZED,
    MEM_RWLOCK_STATE_UNINITIALIZED) <> MEM_RWLOCK_STATE_INITIALIZED then
    RaiseRwLockError('ReleaseWrite', PLATFORM_ERR_INVALID);
  LResult := platform_rwlock_wrunlock(FHandle);
  if LResult <> 0 then
    RaiseRwLockError('ReleaseWrite', LResult);
end;

end.
