unit nextpas.core.time.ticker;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.time.deadline;

type
  TTick = record
    ScheduledAt: TInstant;
    ObservedAt: TInstant;
    LateBy: TDuration;
    Missed: UInt64;
  end;

  TTicker = record
  private
    FRunning: Boolean;
    FInterval: TDuration;
    FNext: TInstant;
  public
    class function Every(const AInterval: TDuration): TTicker; static;

    procedure Start(const AInterval: TDuration);
    procedure Stop;

    function IsRunning: Boolean; inline;
    function GetInterval: TDuration; inline;
    function NextDeadline: TDeadline;
    function Poll(out ATick: TTick): Boolean;
  end;

implementation

{ TTicker }

class function TTicker.Every(const AInterval: TDuration): TTicker;
begin
  Result.FRunning := True;
  Result.FInterval := AInterval;
  Result.FNext := TInstant.Now.Add(AInterval);
end;

procedure TTicker.Start(const AInterval: TDuration);
begin
  FRunning := True;
  FInterval := AInterval;
  FNext := TInstant.Now.Add(AInterval);
end;

procedure TTicker.Stop;
begin
  FRunning := False;
end;

function TTicker.IsRunning: Boolean;
begin
  Result := FRunning;
end;

function TTicker.GetInterval: TDuration;
begin
  Result := FInterval;
end;

function TTicker.NextDeadline: TDeadline;
begin
  if not FRunning then
    Exit(TDeadline.Infinite);
  Result := TDeadline.At(FNext);
end;

function TTicker.Poll(out ATick: TTick): Boolean;
var
  LNow: TInstant;
  LElapsed: TDuration;
  LIntervalNs: Int64;
  LElapsedNs: Int64;
  LMissed: UInt64;
begin
  if not FRunning then
    Exit(False);

  LNow := TInstant.Now;
  if LNow < FNext then
    Exit(False);

  { Tick fired }
  ATick.ScheduledAt := FNext;
  ATick.ObservedAt := LNow;
  LElapsed := LNow.DurationSince(FNext);
  ATick.LateBy := LElapsed;

  { Calculate missed ticks (fixed-rate, skip backlog) }
  LIntervalNs := FInterval.AsNanoseconds;
  if LIntervalNs > 0 then
  begin
    LElapsedNs := LElapsed.AsNanoseconds;
    LMissed := UInt64(LElapsedNs) div UInt64(LIntervalNs);
  end
  else
    LMissed := 0;
  ATick.Missed := LMissed;

  { Advance FNext to next future tick }
  FNext := FNext.Add(FInterval.Mul(Int64(LMissed) + 1));
  Result := True;
end;

end.
