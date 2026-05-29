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
  TEvent = class(TInterfacedObject, IEvent)
  private
    FState: Int32;
    FManualReset: Boolean;
  public
    constructor Create(const AManualReset: Boolean);
    procedure SetEvent;
    procedure Reset;
    procedure Wait;
    function WaitTimeout(const ATimeoutNs: Int64): Boolean;
    function IsSet: Boolean;
  end;

const
  EVENT_UNSET = 0;
  EVENT_SET   = 1;

constructor TEvent.Create(const AManualReset: Boolean);
begin
  inherited Create;
  FState := EVENT_UNSET;
  FManualReset := AManualReset;
end;

procedure TEvent.SetEvent;
begin
  AtomicStore32(FState, EVENT_SET, moRelease);
  if FManualReset then
    platform_wake_address_all(@FState)
  else
    platform_wake_address_one(@FState);
end;

procedure TEvent.Reset;
begin
  AtomicStore32(FState, EVENT_UNSET, moRelease);
end;

procedure TEvent.Wait;
begin
  while AtomicLoad32(FState, moAcquire) = EVENT_UNSET do
    platform_wait_address32(@FState, EVENT_UNSET, -1);
  if not FManualReset then
    AtomicStore32(FState, EVENT_UNSET, moRelease);
end;

function TEvent.WaitTimeout(const ATimeoutNs: Int64): Boolean;
begin
  if AtomicLoad32(FState, moAcquire) = EVENT_SET then
  begin
    if not FManualReset then
      AtomicStore32(FState, EVENT_UNSET, moRelease);
    Exit(True);
  end;
  platform_wait_address32(@FState, EVENT_UNSET, ATimeoutNs);
  Result := AtomicLoad32(FState, moAcquire) = EVENT_SET;
  if Result and (not FManualReset) then
    AtomicStore32(FState, EVENT_UNSET, moRelease);
end;

function TEvent.IsSet: Boolean;
begin
  Result := AtomicLoad32(FState, moAcquire) = EVENT_SET;
end;

function CreateEvent(const AManualReset: Boolean): IEvent;
begin
  Result := TEvent.Create(AManualReset);
end;

end.
