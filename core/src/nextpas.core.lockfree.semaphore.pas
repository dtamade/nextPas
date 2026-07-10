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
    function TryAcquire: Boolean;
    function Acquire: Boolean;
    function AcquireTimeout(const ATimeoutNs: Int64): Boolean;
    procedure Release;
    procedure Close;
    function IsClosed: Boolean;
    function AvailablePermits: Int64;
    function MaxPermits: Int64;
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
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(False);
  repeat
    LOld := AtomicLoad64(FAvailable, moRelaxed);
    if LOld <= 0 then
      Exit(False);
  until AtomicCompareExchange64(FAvailable, LOld, LOld - 1, moAcquire) = LOld;
  Result := True;
end;

function TConcurrentSemaphore.Acquire: Boolean;
var
  LOld: Int64;
begin
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LOld := AtomicLoad64(FAvailable, moRelaxed);
    if LOld <= 0 then
    begin
      CpuPause;
      Continue;
    end;
    if AtomicCompareExchange64(FAvailable, LOld, LOld - 1, moAcquire) = LOld then
      Exit(True);
  end;
end;

function TConcurrentSemaphore.AcquireTimeout(const ATimeoutNs: Int64): Boolean;
var
  LOld: Int64;
  LStart: TInstant;
  LRemaining: Int64;
begin
  LStart := TInstant.Now;
  while True do
  begin
    if AtomicLoad32(FClosed, moAcquire) <> 0 then
      Exit(False);
    LOld := AtomicLoad64(FAvailable, moRelaxed);
    if LOld <= 0 then
    begin
      LRemaining := ATimeoutNs - LStart.Elapsed.AsNanoseconds;
      if LRemaining <= 0 then
        Exit(False);
      CpuPause;
      Continue;
    end;
    if AtomicCompareExchange64(FAvailable, LOld, LOld - 1, moAcquire) = LOld then
      Exit(True);
  end;
end;

procedure TConcurrentSemaphore.Release;
var
  LOld: Int64;
begin
  repeat
    LOld := AtomicLoad64(FAvailable, moAcquire);
    if LOld >= FMaxPermits then
      Exit;
  until AtomicCompareExchange64(FAvailable, LOld, LOld + 1, moRelease) = LOld;
end;

procedure TConcurrentSemaphore.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TConcurrentSemaphore.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TConcurrentSemaphore.AvailablePermits: Int64;
begin
  Result := AtomicLoad64(FAvailable, moAcquire);
end;

function TConcurrentSemaphore.MaxPermits: Int64;
begin
  Result := FMaxPermits;
end;

end.
