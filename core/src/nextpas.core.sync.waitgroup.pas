unit nextpas.core.sync.waitgroup;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf;

type
  {**
   * @desc 无锁 WaitGroup，基于原子操作 + address-wait
   * @note 线程安全
   *}
  TWaitGroup = class(TInterfacedObject, IWaitGroup)
  private
    FCounter: Int32;
    FWaiters: Int32;
  public
    constructor Create;
    procedure Add(const ACount: Int32 = 1);
    procedure Done;
    procedure Wait;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.sync;

{ TWaitGroup }

constructor TWaitGroup.Create;
begin
  inherited Create;
  FCounter := 0;
  FWaiters := 0;
end;

procedure TWaitGroup.Add(const ACount: Int32);
begin
  if ACount <= 0 then
    raise ENextPasError.Create('TWaitGroup.Add: count must be positive');
  InterlockedExchangeAdd(FCounter, ACount);
end;

procedure TWaitGroup.Done;
var
  LNew: Int32;
begin
  LNew := InterlockedExchangeAdd(FCounter, -1) - 1;
  if LNew < 0 then
    raise ENextPasError.Create('TWaitGroup.Done: negative counter (more Done than Add)');
  if LNew = 0 then
  begin
    if InterlockedCompareExchange(FWaiters, 0, 0) > 0 then
      platform_wake_address_all(@FCounter);
  end;
end;

procedure TWaitGroup.Wait;
var
  LCurrent: Int32;
begin
  LCurrent := InterlockedCompareExchange(FCounter, 0, 0);
  if LCurrent <= 0 then
    Exit;

  InterlockedIncrement(FWaiters);
  try
    while True do
    begin
      LCurrent := InterlockedCompareExchange(FCounter, 0, 0);
      if LCurrent <= 0 then
        Break;
      platform_wait_address32(@FCounter, LCurrent, -1);
    end;
  finally
    InterlockedDecrement(FWaiters);
  end;
end;

end.
