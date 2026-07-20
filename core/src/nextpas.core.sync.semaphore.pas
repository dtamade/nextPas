unit nextpas.core.sync.semaphore;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf;

function CreateSemaphore(const AInitial: Int32): ISemaphore;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.errors,
  nextpas.core.platform.sync,
  nextpas.core.time.base;

type
  TSemaphore = class(TInterfacedObject, ISemaphore)
  private
    FCount: Int32;
  public
    constructor Create(const AInitial: Int32);
    procedure Acquire;
    function TryAcquire: Boolean;
    function TryAcquireTimeout(const ATimeoutNs: Int64): Boolean;
    procedure Release;
    procedure Release(const ACount: Int32);
    function Available: Int32;
  end;

constructor TSemaphore.Create(const AInitial: Int32);
begin
  inherited Create;
  if AInitial < 0 then
    raise EArgumentError.Create('Semaphore: initial must be >= 0');
  FCount := AInitial;
end;

function TSemaphore.TryAcquire: Boolean;
var
  LCurrent, LNew: Int32;
begin
  LCurrent := atomic_load(FCount, mo_acquire);
  while True do
  begin
    if LCurrent <= 0 then
      Exit(False);
    LNew := LCurrent - 1;
    if atomic_compare_exchange_strong(FCount, LCurrent, LNew, mo_acq_rel, mo_acquire) then
      Exit(True);
    { LCurrent updated to observed on failure }
  end;
end;

procedure TSemaphore.Acquire;
var
  LSpin: Int32;
begin
  if TryAcquire then
    Exit;
  LSpin := 0;
  while True do
  begin
    if TryAcquire then
      Exit;
    if LSpin < 32 then
    begin
      CpuPause;
      Inc(LSpin);
    end
    else
      platform_wait_address32(@FCount, 0, -1);
  end;
end;

function TSemaphore.TryAcquireTimeout(const ATimeoutNs: Int64): Boolean;
var
  LDeadline: TInstant;
  LRemaining: Int64;
begin
  if TryAcquire then
    Exit(True);
  LDeadline := TInstant.Now;
  while True do
  begin
    LRemaining := ATimeoutNs - LDeadline.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(TryAcquire);
    platform_wait_address32(@FCount, 0, LRemaining);
    if TryAcquire then
      Exit(True);
  end;
end;

procedure TSemaphore.Release;
begin
  atomic_fetch_add(FCount, 1, mo_release);
  platform_wake_address_one(@FCount);
end;

procedure TSemaphore.Release(const ACount: Int32);
var
  LI: Int32;
begin
  if ACount <= 0 then
    raise EArgumentError.Create('Semaphore.Release: count must be > 0');
  atomic_fetch_add(FCount, ACount, mo_release);
  for LI := 0 to ACount - 1 do
    platform_wake_address_one(@FCount);
end;

function TSemaphore.Available: Int32;
begin
  Result := atomic_load(FCount, mo_acquire);
end;

function CreateSemaphore(const AInitial: Int32): ISemaphore;
begin
  Result := TSemaphore.Create(AInitial);
end;

end.
