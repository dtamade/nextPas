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
begin
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  Result := AtomicCompareExchange32(FLocked, 0, 1, moAcquire) = 0;
  if Result then
    AtomicStore64(FOwnerThreadId, Int64(platform_thread_id), moRelaxed);
end;

function TConcurrentMutex.Lock: Boolean;
begin
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    if AtomicCompareExchange32(FLocked, 0, 1, moAcquire) = 0 then
    begin
      AtomicStore64(FOwnerThreadId, Int64(platform_thread_id), moRelaxed);
      Exit(True);
    end;
    CpuPause;
  end;
end;

function TConcurrentMutex.LockTimeout(const ATimeoutNs: Int64): Boolean;
var
  LStart: TInstant;
  LRemaining: Int64;
begin
  LStart := TInstant.Now;
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    if AtomicCompareExchange32(FLocked, 0, 1, moAcquire) = 0 then
    begin
      AtomicStore64(FOwnerThreadId, Int64(platform_thread_id), moRelaxed);
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
  if AtomicLoad64(FOwnerThreadId, moAcquire) <> Int64(platform_thread_id) then
    Exit;
  AtomicStore64(FOwnerThreadId, 0, moRelaxed);
  AtomicStore32(FLocked, 0, moRelease);
end;

procedure TConcurrentMutex.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

destructor TConcurrentMutex.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TConcurrentMutex.IsClosed: Boolean; inline;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TConcurrentMutex.IsLocked: Boolean; inline;
begin
  Result := AtomicLoad32(FLocked, moAcquire) <> 0;
end;

function TConcurrentMutex.IsOwnedByCurrentThread: Boolean; inline;
begin
  Result := IsLocked and
    (AtomicLoad64(FOwnerThreadId, moAcquire) = Int64(platform_thread_id));
end;

end.
