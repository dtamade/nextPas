unit nextpas.core.lockfree.mutex;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeMutexLockResult = (mlLocked, mlClosed, mlTimeout);

  {** @desc 并发互斥锁
    @details 基于原子操作的互斥锁实现。
      支持 Lock/Unlock/TryLock/LockTimeout。
      适用于需要互斥访问的场景。
  }
  TConcurrentMutex = class
  private
    FLocked: Int32;
    FClosed: Int32;
    FOwnerThreadId: Int64;
  public
    constructor Create;
    destructor Destroy; override;
    function TryLock: Boolean;
    function Lock: Boolean;
    function LockTimeout(const ATimeoutNs: Int64): Boolean;
    procedure Unlock;
    procedure Close;
    function IsClosed: Boolean; inline;
    function IsLocked: Boolean; inline;
    function IsOwnedByCurrentThread: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.platform.thread,
  nextpas.core.time.base;

constructor TConcurrentMutex.Create;
begin
  inherited Create;
  FLocked := 0;
  FClosed := 0;
  FOwnerThreadId := 0;
end;

function TConcurrentMutex.TryLock: Boolean;
var
  LExpected: Int32;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  LExpected := 0;
  Result := atomic_compare_exchange_strong(FLocked, LExpected, 1, mo_acquire, mo_relaxed);
  if Result then
    atomic_store_64(FOwnerThreadId, Int64(platform_thread_id), mo_relaxed);
end;

function TConcurrentMutex.Lock: Boolean;
var
  LExpected: Int32;
begin
  Result := False;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    LExpected := 0;
    if atomic_compare_exchange_strong(FLocked, LExpected, 1, mo_acquire, mo_relaxed) then
    begin
      atomic_store_64(FOwnerThreadId, Int64(platform_thread_id), mo_relaxed);
      Exit(True);
    end;
    CpuPause;
  end;
end;

function TConcurrentMutex.LockTimeout(const ATimeoutNs: Int64): Boolean;
var
  LStart: TInstant;
  LRemaining: Int64;
  LExpected: Int32;
begin
  Result := False;
  LStart := TInstant.Now;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    LExpected := 0;
    if atomic_compare_exchange_strong(FLocked, LExpected, 1, mo_acquire, mo_relaxed) then
    begin
      atomic_store_64(FOwnerThreadId, Int64(platform_thread_id), mo_relaxed);
      Exit(True);
    end;
    LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(False);
    CpuPause;
  end;
end;

procedure TConcurrentMutex.Unlock;
begin
  if atomic_load_64(FOwnerThreadId, mo_acquire) <> Int64(platform_thread_id) then
    Exit;
  atomic_store_64(FOwnerThreadId, 0, mo_relaxed);
  atomic_store(FLocked, 0, mo_release);
end;

procedure TConcurrentMutex.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TConcurrentMutex.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TConcurrentMutex.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TConcurrentMutex.IsLocked: Boolean; inline;
begin
  Result := atomic_load(FLocked, mo_acquire) <> 0;
end;

function TConcurrentMutex.IsOwnedByCurrentThread: Boolean; inline;
begin
  Result := IsLocked and
    (atomic_load_64(FOwnerThreadId, mo_acquire) = Int64(platform_thread_id));
end;

end.
