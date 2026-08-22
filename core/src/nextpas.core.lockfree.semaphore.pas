unit nextpas.core.lockfree.semaphore;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeSemaphoreAcquireResult = (saAcquired, saFull, saClosed, saTimeout);

  {** @desc 并发信号量
    @details 基于原子操作的信号量实现。
      支持 Acquire/Release/TryAcquire/AcquireTimeout。
      适用于资源池、限流等场景。
  }
  TConcurrentSemaphore = class
  private
    FMaxPermits: Int64;
    FAvailable: Int64;
    FClosed: Int32;
  public
    constructor Create(const AMaxPermits: Int64);
    destructor Destroy; override;
    function TryAcquire: Boolean;
    function Acquire: Boolean;
    function AcquireTimeout(const ATimeoutNs: Int64): Boolean;
    procedure Release;
    procedure Close;
    function IsClosed: Boolean; inline;
    function AvailablePermits: Int64; inline;
    function MaxPermits: Int64; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

constructor TConcurrentSemaphore.Create(const AMaxPermits: Int64);
begin
  if AMaxPermits <= 0 then
    raise EArgumentError.Create('TConcurrentSemaphore: max permits must be > 0');
  inherited Create;
  FMaxPermits := AMaxPermits;
  FAvailable := AMaxPermits;
  FClosed := 0;
end;

function TConcurrentSemaphore.TryAcquire: Boolean;
var
  LOld: Int64;
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(False);
  repeat
    LOld := atomic_load_64(FAvailable, mo_relaxed);
    if LOld <= 0 then
      Exit(False);
  until atomic_compare_exchange_strong_64(FAvailable, LOld, LOld - 1, mo_acquire, mo_acquire);
  Result := True;
end;

function TConcurrentSemaphore.Acquire: Boolean;
var
  LOld: Int64;
begin
  Result := False;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    LOld := atomic_load_64(FAvailable, mo_relaxed);
    if LOld <= 0 then
    begin
      CpuPause;
      Continue;
    end;
    if atomic_compare_exchange_strong_64(FAvailable, LOld, LOld - 1, mo_acquire, mo_acquire) then
      Exit(True);
  end;
end;

function TConcurrentSemaphore.AcquireTimeout(const ATimeoutNs: Int64): Boolean;
var
  LOld: Int64;
  LStart: TInstant;
  LRemaining: Int64;
begin
  Result := False;
  LStart := TInstant.Now;
  while True do
  begin
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(False);
    LOld := atomic_load_64(FAvailable, mo_relaxed);
    if LOld <= 0 then
    begin
      LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
      if LRemaining <= 0 then
        Exit(False);
      CpuPause;
      Continue;
    end;
    if atomic_compare_exchange_strong_64(FAvailable, LOld, LOld - 1, mo_acquire, mo_acquire) then
      Exit(True);
  end;
end;

procedure TConcurrentSemaphore.Release;
var
  LOld: Int64;
begin
  repeat
    LOld := atomic_load_64(FAvailable, mo_acquire);
    if LOld >= FMaxPermits then
      Exit;
  until atomic_compare_exchange_strong_64(FAvailable, LOld, LOld + 1, mo_release, mo_relaxed);
end;

procedure TConcurrentSemaphore.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

destructor TConcurrentSemaphore.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TConcurrentSemaphore.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TConcurrentSemaphore.AvailablePermits: Int64; inline;
begin
  Result := atomic_load_64(FAvailable, mo_acquire);
end;

function TConcurrentSemaphore.MaxPermits: Int64; inline;
begin
  Result := FMaxPermits;
end;

end.
