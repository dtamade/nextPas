unit nextpas.core.sync.spinlock;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf;

function CreateSpinLock: ISpinLock;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.thread;

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
