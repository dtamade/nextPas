unit nextpas.core.time.timer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.time.deadline;

type
  TTimerState = (tsIdle, tsArmed);

  TTimer = record
  private
    FState: TTimerState;
    FDeadline: TDeadline;
  public
    class function Create: TTimer; static;
    class function After(const ADelay: TDuration): TTimer; static;

    procedure Arm(const ADelay: TDuration);
    procedure ArmAt(const ADeadline: TDeadline);
    procedure Cancel;

    function IsArmed: Boolean; inline;
    function GetDeadline: TDeadline; inline;
    function Poll: Boolean;
  end;

implementation

{ TTimer }

class function TTimer.Create: TTimer;
begin
  Result.FState := tsIdle;
  Result.FDeadline := TDeadline.Infinite;
end;

class function TTimer.After(const ADelay: TDuration): TTimer;
begin
  Result.FState := tsArmed;
  Result.FDeadline := TDeadline.After(ADelay);
end;

procedure TTimer.Arm(const ADelay: TDuration);
begin
  FState := tsArmed;
  FDeadline := TDeadline.After(ADelay);
end;

procedure TTimer.ArmAt(const ADeadline: TDeadline);
begin
  FState := tsArmed;
  FDeadline := ADeadline;
end;

procedure TTimer.Cancel;
begin
  FState := tsIdle;
  FDeadline := TDeadline.Infinite;
end;

function TTimer.IsArmed: Boolean;
begin
  Result := FState = tsArmed;
end;

function TTimer.GetDeadline: TDeadline;
begin
  Result := FDeadline;
end;

function TTimer.Poll: Boolean;
begin
  if FState <> tsArmed then
    Exit(False);
  if not FDeadline.IsExpired then
    Exit(False);
  { Fire: disarm and return True (one-shot) }
  FState := tsIdle;
  FDeadline := TDeadline.Infinite;
  Result := True;
end;

end.
