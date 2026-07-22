unit nextpas.core.sync.waitgroup;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf,
  nextpas.core.time.base;

type
  TWaitGroup = class(TInterfacedObject, IWaitGroup)
  private
    FCounter: Int32;
    FWaiters: Int32;
  public
    constructor Create;
    procedure Add(const ACount: Int32 = 1);
    procedure Done;
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function WaitTimeout(const ATimeout: TDuration): Boolean;
  end;

implementation

uses
  nextpas.core.sync.errors,
  nextpas.core.platform.sync;

constructor TWaitGroup.Create;
begin
  inherited Create;
  FCounter := 0;
  FWaiters := 0;
end;

procedure TWaitGroup.Add(const ACount: Int32);
begin
  if ACount <= 0 then
    SyncRaiseArg('TWaitGroup.Add: count must be positive');
  InterlockedExchangeAdd(FCounter, ACount);
end;

procedure TWaitGroup.Done;
var
  LNew: Int32;
begin
  LNew := InterlockedExchangeAdd(FCounter, -1) - 1;
  if LNew < 0 then
    SyncRaiseInvalidOp('TWaitGroup.Done: negative counter (more Done than Add)');
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

function TWaitGroup.WaitTimeout(const ATimeoutNs: Int64): Boolean;
var
  LCurrent: Int32;
  LDeadline: TInstant;
  LRemaining: Int64;
begin
  LCurrent := InterlockedCompareExchange(FCounter, 0, 0);
  if LCurrent <= 0 then
    Exit(True);

  InterlockedIncrement(FWaiters);
  try
    LDeadline := TInstant.Now;
    while True do
    begin
      LCurrent := InterlockedCompareExchange(FCounter, 0, 0);
      if LCurrent <= 0 then
        Exit(True);
      LRemaining := ATimeoutNs - LDeadline.Elapsed.AsNanoseconds;
      if LRemaining <= 0 then
        Exit(False);
      platform_wait_address32(@FCounter, LCurrent, LRemaining);
    end;
  finally
    InterlockedDecrement(FWaiters);
  end;
end;

function TWaitGroup.WaitTimeout(const ATimeout: TDuration): Boolean;
begin
  Result := WaitTimeout(ATimeout.AsNanoseconds);
end;

end.
