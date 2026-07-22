unit nextpas.core.sync.latch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf,
  nextpas.core.time.base;

function CreateLatch(const ACount: Int32): ILatch;

implementation

uses
  nextpas.core.sync.errors,
  nextpas.core.platform.sync;

type
  TLatch = class(TInterfacedObject, ILatch)
  private
    FRemaining: Int32;
    FWaiters: Int32;
  public
    constructor Create(const ACount: Int32);
    procedure CountDown(const ACount: Int32 = 1);
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function WaitTimeout(const ATimeout: TDuration): Boolean;
    function TryWait: Boolean;
    function Remaining: Int32;
  end;

constructor TLatch.Create(const ACount: Int32);
begin
  inherited Create;
  if ACount < 0 then
    SyncRaiseArg('TLatch: count must be >= 0');
  FRemaining := ACount;
  FWaiters := 0;
end;

procedure TLatch.CountDown(const ACount: Int32);
var
  LOld, LNew: Int32;
begin
  if ACount <= 0 then
    SyncRaiseArg('TLatch.CountDown: count must be positive');
  while True do
  begin
    LOld := InterlockedCompareExchange(FRemaining, 0, 0);
    if LOld = 0 then
      Exit;
    if ACount > LOld then
      SyncRaiseInvalidOp('TLatch.CountDown: would go negative');
    LNew := LOld - ACount;
    if InterlockedCompareExchange(FRemaining, LNew, LOld) = LOld then
    begin
      if LNew = 0 then
      begin
        if InterlockedCompareExchange(FWaiters, 0, 0) > 0 then
          platform_wake_address_all(@FRemaining);
      end;
      Exit;
    end;
  end;
end;

procedure TLatch.Wait;
var
  LCurrent: Int32;
begin
  LCurrent := InterlockedCompareExchange(FRemaining, 0, 0);
  if LCurrent <= 0 then
    Exit;

  InterlockedIncrement(FWaiters);
  try
    while True do
    begin
      LCurrent := InterlockedCompareExchange(FRemaining, 0, 0);
      if LCurrent <= 0 then
        Break;
      platform_wait_address32(@FRemaining, LCurrent, -1);
    end;
  finally
    InterlockedDecrement(FWaiters);
  end;
end;

function TLatch.WaitTimeout(const ATimeoutNs: Int64): Boolean;
var
  LCurrent: Int32;
  LDeadline: TInstant;
  LRemainingNs: Int64;
begin
  LCurrent := InterlockedCompareExchange(FRemaining, 0, 0);
  if LCurrent <= 0 then
    Exit(True);

  InterlockedIncrement(FWaiters);
  try
    LDeadline := TInstant.Now;
    while True do
    begin
      LCurrent := InterlockedCompareExchange(FRemaining, 0, 0);
      if LCurrent <= 0 then
        Exit(True);
      LRemainingNs := ATimeoutNs - LDeadline.Elapsed.AsNanoseconds;
      if LRemainingNs <= 0 then
        Exit(False);
      platform_wait_address32(@FRemaining, LCurrent, LRemainingNs);
    end;
  finally
    InterlockedDecrement(FWaiters);
  end;
end;

function TLatch.WaitTimeout(const ATimeout: TDuration): Boolean;
begin
  Result := WaitTimeout(ATimeout.AsNanoseconds);
end;

function TLatch.TryWait: Boolean;
begin
  Result := InterlockedCompareExchange(FRemaining, 0, 0) <= 0;
end;

function TLatch.Remaining: Int32;
begin
  Result := InterlockedCompareExchange(FRemaining, 0, 0);
end;

function CreateLatch(const ACount: Int32): ILatch;
begin
  Result := TLatch.Create(ACount);
end;

end.
