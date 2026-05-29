unit nextpas.core.sync.event;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.intf;

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
  LCur := AtomicLoad32(FGen, moAcquire);
  if (LCur and 1) = 1 then
    Exit;
  AtomicFetchAdd32(FGen, 1, moRelease);
  platform_wake_address_all(@FGen);
end;

procedure TManualResetEvent.Reset;
var
  LCur: Int32;
begin
  LCur := AtomicLoad32(FGen, moAcquire);
  if (LCur and 1) = 0 then
    Exit;
  AtomicFetchAdd32(FGen, 1, moRelease);
end;

procedure TManualResetEvent.Wait;
var
  LSnap: Int32;
begin
  LSnap := AtomicLoad32(FGen, moAcquire);
  if (LSnap and 1) = 1 then
    Exit;
  while True do
  begin
    platform_wait_address32(@FGen, LSnap, -1);
    LSnap := AtomicLoad32(FGen, moAcquire);
    if (LSnap and 1) = 1 then
      Exit;
  end;
end;

function TManualResetEvent.WaitTimeout(const ATimeoutNs: Int64): Boolean;
var
  LSnap: Int32;
begin
  LSnap := AtomicLoad32(FGen, moAcquire);
  if (LSnap and 1) = 1 then
    Exit(True);
  platform_wait_address32(@FGen, LSnap, ATimeoutNs);
  LSnap := AtomicLoad32(FGen, moAcquire);
  Result := (LSnap and 1) = 1;
end;

function TManualResetEvent.IsSet: Boolean;
begin
  Result := (AtomicLoad32(FGen, moAcquire) and 1) = 1;
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
  LOld: Int32;
begin
  LOld := AtomicCompareExchange32(FState, 0, 1, moRelease);
  if LOld = 0 then
    platform_wake_address_one(@FState);
end;

procedure TAutoResetEvent.Reset;
begin
  AtomicStore32(FState, 0, moRelease);
end;

procedure TAutoResetEvent.Wait;
begin
  while AtomicCompareExchange32(FState, 1, 0, moAcquire) <> 1 do
    platform_wait_address32(@FState, 0, -1);
end;

function TAutoResetEvent.WaitTimeout(const ATimeoutNs: Int64): Boolean;
begin
  if AtomicCompareExchange32(FState, 1, 0, moAcquire) = 1 then
    Exit(True);
  platform_wait_address32(@FState, 0, ATimeoutNs);
  Result := AtomicCompareExchange32(FState, 1, 0, moAcquire) = 1;
end;

function TAutoResetEvent.IsSet: Boolean;
begin
  Result := AtomicLoad32(FState, moAcquire) = 1;
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
