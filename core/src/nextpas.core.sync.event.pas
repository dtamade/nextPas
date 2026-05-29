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

constructor TEvent.Create(const AManualReset: Boolean);
begin
  inherited Create;
  FState := 0;
  FManualReset := AManualReset;
end;

procedure TEvent.SetEvent;
begin
  AtomicFetchAdd32(FState, 1, moRelease);
  if FManualReset then
    platform_wake_address_all(@FState)
  else
    platform_wake_address_one(@FState);
end;

procedure TEvent.Reset;
begin
  AtomicStore32(FState, 0, moRelease);
end;

procedure TEvent.Wait;
var
  LSnap: Int32;
begin
  if FManualReset then
  begin
    while AtomicLoad32(FState, moAcquire) = 0 do
      platform_wait_address32(@FState, 0, -1);
  end
  else
  begin
    repeat
      LSnap := AtomicLoad32(FState, moAcquire);
      if LSnap = 0 then
      begin
        platform_wait_address32(@FState, 0, -1);
        Continue;
      end;
    until AtomicCompareExchange32(FState, LSnap, LSnap - 1, moAcqRel) = LSnap;
  end;
end;

function TEvent.WaitTimeout(const ATimeoutNs: Int64): Boolean;
var
  LSnap: Int32;
begin
  if FManualReset then
  begin
    if AtomicLoad32(FState, moAcquire) > 0 then
      Exit(True);
    platform_wait_address32(@FState, 0, ATimeoutNs);
    Result := AtomicLoad32(FState, moAcquire) > 0;
  end
  else
  begin
    LSnap := AtomicLoad32(FState, moAcquire);
    if LSnap > 0 then
    begin
      if AtomicCompareExchange32(FState, LSnap, LSnap - 1, moAcqRel) = LSnap then
        Exit(True);
    end;
    platform_wait_address32(@FState, 0, ATimeoutNs);
    repeat
      LSnap := AtomicLoad32(FState, moAcquire);
      if LSnap = 0 then
        Exit(False);
    until AtomicCompareExchange32(FState, LSnap, LSnap - 1, moAcqRel) = LSnap;
    Result := True;
  end;
end;

function TEvent.IsSet: Boolean;
begin
  Result := AtomicLoad32(FState, moAcquire) > 0;
end;

function CreateEvent(const AManualReset: Boolean): IEvent;
begin
  Result := TEvent.Create(AManualReset);
end;

end.
