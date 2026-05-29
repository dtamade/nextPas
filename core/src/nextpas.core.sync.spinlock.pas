unit nextpas.core.sync.spinlock;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf;

type
  ISpinLock = interface(ILock)
    ['{E1F2A3B4-C5D6-7890-ABCD-EF1234560011}']
  end;

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
begin
  LSpins := 0;
  while AtomicCompareExchange32(FLocked, 0, 1, moAcquire) <> 0 do
  begin
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
begin
  Result := AtomicCompareExchange32(FLocked, 0, 1, moAcquire) = 0;
end;

procedure TSpinLock.Release;
begin
  AtomicStore32(FLocked, 0, moRelease);
end;

function TSpinLock.Lock: ILockGuard;
begin
  Acquire;
  Result := TSpinLockGuard.Create(Self);
end;

constructor TSpinLockGuard.Create(const AOwner: ISpinLock);
begin
  inherited Create;
  FOwner := AOwner;
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
