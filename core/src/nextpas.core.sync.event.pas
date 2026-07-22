unit nextpas.core.sync.event;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf,
  nextpas.core.time.base;

function CreateEvent(const AManualReset: Boolean = True): IEvent;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.sync;

type
  TManualResetEvent = class(TInterfacedObject, IEvent)
  private
    FGen: Int32;
  public
    constructor Create;
    procedure SetEvent;
    procedure Reset;
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function WaitTimeout(const ATimeout: TDuration): Boolean;
    function IsSet: Boolean;
  end;

  TAutoResetEvent = class(TInterfacedObject, IEvent)
  private
    FState: Int32;
  public
    constructor Create;
    procedure SetEvent;
    procedure Reset;
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function WaitTimeout(const ATimeout: TDuration): Boolean;
    function IsSet: Boolean;
  end;

{ TManualResetEvent — generation-based.
  Even generation = unset, odd generation = set.
  SetEvent increments to odd; Reset increments to even.
  Waiters snapshot generation and sleep until it changes to odd. }

constructor TManualResetEvent.Create;
begin
  inherited Create;
  FGen := 0;
end;

procedure TManualResetEvent.SetEvent;
var
  LCur: Int32;
begin
  LCur := atomic_load(FGen, mo_acquire);
  while True do
  begin
    if (LCur and 1) = 1 then
      Exit;
    if atomic_compare_exchange_strong(FGen, LCur, LCur + 1, mo_acq_rel, mo_acquire) then
    begin
      platform_wake_address_all(@FGen);
      Exit;
    end;
  end;
end;

procedure TManualResetEvent.Reset;
var
  LCur: Int32;
begin
  LCur := atomic_load(FGen, mo_acquire);
  while True do
  begin
    if (LCur and 1) = 0 then
      Exit;
    if atomic_compare_exchange_strong(FGen, LCur, LCur + 1, mo_acq_rel, mo_acquire) then
      Exit;
  end;
end;

procedure TManualResetEvent.Wait;
var
  LSnap: Int32;
begin
  LSnap := atomic_load(FGen, mo_acquire);
  if (LSnap and 1) = 1 then
    Exit;
  while True do
  begin
    platform_wait_address32(@FGen, LSnap, -1);
    LSnap := atomic_load(FGen, mo_acquire);
    if (LSnap and 1) = 1 then
      Exit;
  end;
end;

function TManualResetEvent.WaitTimeout(const ATimeoutNs: Int64): Boolean;
var
  LSnap: Int32;
begin
  LSnap := atomic_load(FGen, mo_acquire);
  if (LSnap and 1) = 1 then
    Exit(True);
  platform_wait_address32(@FGen, LSnap, ATimeoutNs);
  LSnap := atomic_load(FGen, mo_acquire);
  Result := (LSnap and 1) = 1;
end;

function TManualResetEvent.WaitTimeout(const ATimeout: TDuration): Boolean;
begin
  Result := WaitTimeout(ATimeout.AsNanoseconds);
end;

function TManualResetEvent.IsSet: Boolean;
begin
  Result := (atomic_load(FGen, mo_acquire) and 1) = 1;
end;

{ TAutoResetEvent — binary permit via CAS.
  FState: 0 = unset, 1 = set.
  SetEvent: CAS 0->1 (idempotent, single permit).
  Wait: CAS 1->0 to consume. }

constructor TAutoResetEvent.Create;
begin
  inherited Create;
  FState := 0;
end;

procedure TAutoResetEvent.SetEvent;
var
  LExpected: Int32;
begin
  LExpected := 0;
  if atomic_compare_exchange_strong(FState, LExpected, 1, mo_release, mo_relaxed) then
    platform_wake_address_one(@FState);
end;

procedure TAutoResetEvent.Reset;
begin
  atomic_store(FState, 0, mo_release);
end;

procedure TAutoResetEvent.Wait;
var
  LExpected: Int32;
begin
  while True do
  begin
    LExpected := 1;
    if atomic_compare_exchange_strong(FState, LExpected, 0, mo_acquire, mo_relaxed) then
      Exit;
    platform_wait_address32(@FState, 0, -1);
  end;
end;

function TAutoResetEvent.WaitTimeout(const ATimeoutNs: Int64): Boolean;
var
  LExpected: Int32;
begin
  LExpected := 1;
  if atomic_compare_exchange_strong(FState, LExpected, 0, mo_acquire, mo_relaxed) then
    Exit(True);
  platform_wait_address32(@FState, 0, ATimeoutNs);
  LExpected := 1;
  Result := atomic_compare_exchange_strong(FState, LExpected, 0, mo_acquire, mo_relaxed);
end;

function TAutoResetEvent.WaitTimeout(const ATimeout: TDuration): Boolean;
begin
  Result := WaitTimeout(ATimeout.AsNanoseconds);
end;

function TAutoResetEvent.IsSet: Boolean;
begin
  Result := atomic_load(FState, mo_acquire) = 1;
end;

{ Factory }

function CreateEvent(const AManualReset: Boolean): IEvent;
begin
  if AManualReset then
    Result := TManualResetEvent.Create
  else
    Result := TAutoResetEvent.Create;
end;

end.
