unit nextpas.core.sync.mutex;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf,
  nextpas.core.platform.sync;

type
  {**
   * @desc 标准互斥锁，基于 platform pthread_mutex (ERRORCHECK)
   * @note 非递归，同一线程重入会返回错误
   *}
  TMutex = class(TInterfacedObject, ILock, IMutex, INativeMutex)
  private
    FHandle: TPlatformMutex;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Acquire;
    function TryAcquire: Boolean;
    procedure Release;
    function Lock: ILockGuard;
    function NativeHandle: Pointer;
  end;

  {**
   * @desc 高性能互斥锁，基于 futex 三态协议
   * @note 快速路径单次 CAS，慢速路径 futex 阻塞
   * @note 不实现 INativeMutex — 不可与 ICondVar 配对
   *}
  TFutexMutex = class(TInterfacedObject, ILock, IMutex)
  private
    FState: Int32;
  public
    constructor Create;
    procedure Acquire;
    function TryAcquire: Boolean;
    procedure Release;
    function Lock: ILockGuard;
  end;

  {**
   * @desc 递归互斥锁，基于 platform pthread_mutex (RECURSIVE)
   * @note 同一线程可重入；必须配对相同次数的 Release
   * @note 实现 INativeMutex，可与 ICondVar 配对
   *}
  TRecursiveMutex = class(TInterfacedObject, ILock, IMutex, INativeMutex)
  private
    FHandle: TPlatformMutex;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Acquire;
    function TryAcquire: Boolean;
    procedure Release;
    function Lock: ILockGuard;
    function NativeHandle: Pointer;
  end;

implementation

uses
  nextpas.core.sync.errors,
  nextpas.core.atomic,
  nextpas.core.platform.thread;

type
  TLockGuardImpl = class(TInterfacedObject, ILockGuard)
  private
    FLock: ILock;
  public
    constructor Create(const ALock: ILock);
    destructor Destroy; override;
  end;

{ TLockGuardImpl }

constructor TLockGuardImpl.Create(const ALock: ILock);
begin
  inherited Create;
  FLock := ALock;
end;

destructor TLockGuardImpl.Destroy;
begin
  if FLock <> nil then
    FLock.Release;
  inherited;
end;

{ TMutex }

constructor TMutex.Create;
var
  LRet: Int32;
begin
  inherited Create;
  LRet := platform_mutex_init(FHandle, PLATFORM_MUTEX_ERRORCHECK);
  if LRet <> 0 then
    SyncRaiseOpFailed('TMutex', 'Create', LRet);
end;

destructor TMutex.Destroy;
var
  LRet: Int32;
begin
  LRet := platform_mutex_destroy(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TMutex', 'Destroy', LRet);
  inherited;
end;

procedure TMutex.Acquire;
var
  LRet: Int32;
begin
  LRet := platform_mutex_lock(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TMutex', 'Acquire', LRet);
end;

function TMutex.TryAcquire: Boolean;
begin
  Result := platform_mutex_trylock(FHandle) = 0;
end;

procedure TMutex.Release;
var
  LRet: Int32;
begin
  LRet := platform_mutex_unlock(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TMutex', 'Release', LRet);
end;

function TMutex.Lock: ILockGuard;
begin
  Acquire;
  Result := TLockGuardImpl.Create(Self);
end;

function TMutex.NativeHandle: Pointer;
begin
  Result := @FHandle;
end;

{ TFutexMutex }

const
  STATE_UNLOCKED           = 0;
  STATE_LOCKED             = 1;
  STATE_LOCKED_WITH_WAITERS = 2;

constructor TFutexMutex.Create;
begin
  inherited Create;
  FState := STATE_UNLOCKED;
end;

procedure TFutexMutex.Acquire;
var
  LOld: Int32;
  LIter: Int32;
  LDelay: Int32;
  LPause: Int32;
begin
  LOld := InterlockedCompareExchange(FState, STATE_LOCKED, STATE_UNLOCKED);
  if LOld = STATE_UNLOCKED then
    Exit;
  // 指数退避 + 自适应让步：避免固定 40 次 PAUSE 的高争用饥饿
  LDelay := 1;
  for LIter := 0 to 7 do
  begin
    for LPause := 1 to LDelay do
      cpu_pause;
    if FState = STATE_UNLOCKED then
    begin
      LOld := InterlockedCompareExchange(FState, STATE_LOCKED, STATE_UNLOCKED);
      if LOld = STATE_UNLOCKED then
        Exit;
    end;
    if LIter >= 2 then
      platform_thread_yield;
    if LDelay < 32 then
      LDelay := LDelay shl 1;
  end;

  while True do
  begin
    LOld := InterlockedExchange(FState, STATE_LOCKED_WITH_WAITERS);
    if LOld = STATE_UNLOCKED then
      Exit;
    platform_wait_address32(@FState, STATE_LOCKED_WITH_WAITERS, -1);
  end;
end;

function TFutexMutex.TryAcquire: Boolean;
begin
  Result := InterlockedCompareExchange(FState, STATE_LOCKED, STATE_UNLOCKED) = STATE_UNLOCKED;
end;

procedure TFutexMutex.Release;
var
  LOld: Int32;
begin
  LOld := InterlockedExchange(FState, STATE_UNLOCKED);
  if LOld = STATE_LOCKED_WITH_WAITERS then
    platform_wake_address_one(@FState);
end;

function TFutexMutex.Lock: ILockGuard;
begin
  Acquire;
  Result := TLockGuardImpl.Create(Self);
end;

{ TRecursiveMutex }

constructor TRecursiveMutex.Create;
var
  LRet: Int32;
begin
  inherited Create;
  LRet := platform_mutex_init(FHandle, PLATFORM_MUTEX_RECURSIVE);
  if LRet <> 0 then
    SyncRaiseOpFailed('TRecursiveMutex', 'Create', LRet);
end;

destructor TRecursiveMutex.Destroy;
var
  LRet: Int32;
begin
  LRet := platform_mutex_destroy(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TRecursiveMutex', 'Destroy', LRet);
  inherited;
end;

procedure TRecursiveMutex.Acquire;
var
  LRet: Int32;
begin
  LRet := platform_mutex_lock(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TRecursiveMutex', 'Acquire', LRet);
end;

function TRecursiveMutex.TryAcquire: Boolean;
begin
  Result := platform_mutex_trylock(FHandle) = 0;
end;

procedure TRecursiveMutex.Release;
var
  LRet: Int32;
begin
  LRet := platform_mutex_unlock(FHandle);
  if LRet <> 0 then
    SyncRaiseOpFailed('TRecursiveMutex', 'Release', LRet);
end;

function TRecursiveMutex.Lock: ILockGuard;
begin
  Acquire;
  Result := TLockGuardImpl.Create(Self);
end;

function TRecursiveMutex.NativeHandle: Pointer;
begin
  Result := @FHandle;
end;

end.
