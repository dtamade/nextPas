unit nextpas.core.sync.notify;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf,
  nextpas.core.time.base;

function CreateNotify: INotify;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.sync;

type
  { NotifyOne: always deposits one sticky permit and wakes one waiter.
    NotifyAll: bumps epoch so all current waiters observe a change (no permit). }
  TNotify = class(TInterfacedObject, INotify)
  private
    FPermits: Int32;
    FEpoch: Int32;
  public
    constructor Create;
    procedure NotifyOne;
    procedure NotifyAll;
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function WaitTimeout(const ATimeout: TDuration): Boolean;
  end;

constructor TNotify.Create;
begin
  inherited Create;
  FPermits := 0;
  FEpoch := 0;
end;

function TryConsumePermit(var APermits: Int32): Boolean;
var
  LCur: Int32;
begin
  LCur := atomic_load(APermits, mo_acquire);
  while LCur > 0 do
  begin
    if atomic_compare_exchange_strong(APermits, LCur, LCur - 1, mo_acq_rel, mo_acquire) then
      Exit(True);
  end;
  Result := False;
end;

procedure TNotify.NotifyOne;
begin
  InterlockedIncrement(FPermits);
  platform_wake_address_one(@FEpoch);
end;

procedure TNotify.NotifyAll;
begin
  { Wake current waiters only (tokio notify_waiters). Clear sticky permits so a
    prior NotifyOne does not mix with the broadcast generation. }
  atomic_store(FPermits, 0, mo_release);
  InterlockedIncrement(FEpoch);
  platform_wake_address_all(@FEpoch);
end;

procedure TNotify.Wait;
var
  LEpoch: Int32;
begin
  if TryConsumePermit(FPermits) then
    Exit;

  LEpoch := InterlockedCompareExchange(FEpoch, 0, 0);
  while True do
  begin
    if TryConsumePermit(FPermits) then
      Exit;
    if InterlockedCompareExchange(FEpoch, 0, 0) <> LEpoch then
      Exit;
    platform_wait_address32(@FEpoch, LEpoch, -1);
  end;
end;

function TNotify.WaitTimeout(const ATimeoutNs: Int64): Boolean;
var
  LEpoch: Int32;
  LDeadline: TInstant;
  LRemaining: Int64;
begin
  if TryConsumePermit(FPermits) then
    Exit(True);

  LEpoch := InterlockedCompareExchange(FEpoch, 0, 0);
  LDeadline := TInstant.Now;
  while True do
  begin
    if TryConsumePermit(FPermits) then
      Exit(True);
    if InterlockedCompareExchange(FEpoch, 0, 0) <> LEpoch then
      Exit(True);
    LRemaining := ATimeoutNs - LDeadline.Elapsed.AsNanoseconds;
    if LRemaining <= 0 then
      Exit(False);
    platform_wait_address32(@FEpoch, LEpoch, LRemaining);
  end;
end;

function TNotify.WaitTimeout(const ATimeout: TDuration): Boolean;
begin
  Result := WaitTimeout(ATimeout.AsNanoseconds);
end;

function CreateNotify: INotify;
begin
  Result := TNotify.Create;
end;

end.
