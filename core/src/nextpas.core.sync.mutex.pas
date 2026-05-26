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
  TMutex = class(TInterfacedObject, ILock, IMutex)
  private
    FHandle: TPlatformMutex;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Acquire;
    function TryAcquire: Boolean;
    procedure Release;
    function Lock: ILockGuard;
  end;

  {**
   * @desc 高性能互斥锁，基于 futex 三态协议
   * @note 快速路径单次 CAS，慢速路径 futex 阻塞
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

implementation

uses
  SysUtils, nextpas.core.errors;

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
    raise ENextPasError.CreateFmt('TMutex.Create failed: %d', [LRet]);
end;

destructor TMutex.Destroy;
begin
  platform_mutex_destroy(FHandle);
  inherited;
end;

procedure TMutex.Acquire;
var
  LRet: Int32;
begin
  LRet := platform_mutex_lock(FHandle);
  if LRet <> 0 then
    raise ENextPasError.CreateFmt('TMutex.Acquire failed: %d', [LRet]);
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
    raise ENextPasError.CreateFmt('TMutex.Release failed: %d', [LRet]);
end;

function TMutex.Lock: ILockGuard;
begin
  Acquire;
  Result := TLockGuardImpl.Create(Self);
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
  LSpins: Int32;
begin
  // Fast path: CAS unlocked -> locked
  LOld := InterlockedCompareExchange(FState, STATE_LOCKED, STATE_UNLOCKED);
  if LOld = STATE_UNLOCKED then
    Exit;

  // Medium path: short spin
  for LSpins := 0 to 39 do
  begin
    if FState = STATE_UNLOCKED then
    begin
      LOld := InterlockedCompareExchange(FState, STATE_LOCKED, STATE_UNLOCKED);
      if LOld = STATE_UNLOCKED then
        Exit;
    end;
    {$IFDEF CPUX86_64}
    asm
      pause
    end;
    {$ENDIF}
  end;

  // Slow path: mark as contended and wait
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

end.
