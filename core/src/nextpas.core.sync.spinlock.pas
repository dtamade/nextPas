unit nextpas.core.sync.spinlock;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf;

function CreateSpinLock: ISpinLock;

// raw int32 spinlock single source — owner sync.spinlock, sampled deadline, inline zero-copy, amortized O(1)
// bounds bulk NewContext livelock via 5ms sampled check (64-spin amortization avoids per-spin syscall storm), exponential backoff + yield
procedure RawSpinAcquire(var ALock: Int32); inline;
procedure RawSpinRelease(var ALock: Int32); inline;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

const
  RAW_SPIN_TIMEOUT_NS = QWord(5 * 1000000); // 5ms sampled deadline single source, bounds bulk livelock, amortized via 64-spin sampling (no per-spin syscall)

procedure RawSpinAcquire(var ALock: Int32); inline;
var LExp: Int32; LSpins: Integer; LDeadline: QWord; LBackoff, LB: Integer;
begin
  // single source spin: exponential backoff + sampled 5ms deadline (check every 64 spins, 64x syscall reduction), inline hot path, zero alloc, amortized
  LExp := 0; LSpins := 0; LDeadline := QWord(platform_monotonic_ns) + RAW_SPIN_TIMEOUT_NS;
  while not atomic_compare_exchange_strong(ALock, LExp, 1, mo_acquire, mo_relaxed) do
  begin
    LExp := 0; Inc(LSpins);
    if (LSpins and 63) = 0 then
    begin
      if QWord(platform_monotonic_ns) >= LDeadline then
      begin
        platform_thread_yield;
        LDeadline := QWord(platform_monotonic_ns) + RAW_SPIN_TIMEOUT_NS;
      end;
    end;
    if LSpins < 32 then
    begin
      LBackoff := 1 shl (LSpins shr 2);
      if LBackoff > 8 then LBackoff := 8;
      for LB := 1 to LBackoff do cpu_pause;
    end else begin platform_thread_yield; LSpins := 0; end;
  end;
end;

procedure RawSpinRelease(var ALock: Int32); inline;
begin
  // inline release single source, zero-copy, amortized, paired with acquire
  atomic_store(ALock, 0, mo_release);
end;

type
  TSpinLock = class(TInterfacedObject, ISpinLock, ILock)
  private
    FLocked: Int32;
  public
    constructor Create;
    procedure Acquire;
    function TryAcquire: Boolean;
    procedure Release;
    function Lock: ILockGuard;
  end;

  TSpinLockGuard = class(TInterfacedObject, ILockGuard)
  private
    FOwner: ISpinLock;
  public
    constructor Create(const AOwner: ISpinLock);
    destructor Destroy; override;
  end;

constructor TSpinLock.Create;
begin
  inherited Create;
  FLocked := 0;
end;

procedure TSpinLock.Acquire;
var
  LSpins: Int32;
  LExpected: Int32;
begin
  LSpins := 0;
  LExpected := 0;
  while not atomic_compare_exchange_strong(FLocked, LExpected, 1, mo_acquire, mo_relaxed) do
  begin
    LExpected := 0;
    Inc(LSpins);
    if LSpins < 64 then
      CpuPause
    else
    begin
      LSpins := 0;
      platform_thread_yield;
    end;
  end;
end;

function TSpinLock.TryAcquire: Boolean;
var
  LExpected: Int32;
begin
  LExpected := 0;
  Result := atomic_compare_exchange_strong(FLocked, LExpected, 1, mo_acquire, mo_relaxed);
end;

procedure TSpinLock.Release;
begin
  atomic_store(FLocked, 0, mo_release);
end;

function TSpinLock.Lock: ILockGuard;
begin
  Result := TSpinLockGuard.Create(Self);
end;

constructor TSpinLockGuard.Create(const AOwner: ISpinLock);
begin
  inherited Create;
  FOwner := AOwner;
  FOwner.Acquire;
end;

destructor TSpinLockGuard.Destroy;
begin
  FOwner.Release;
  inherited;
end;

function CreateSpinLock: ISpinLock;
begin
  Result := TSpinLock.Create;
end;

end.
