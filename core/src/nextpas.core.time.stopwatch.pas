unit nextpas.core.time.stopwatch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base;

type
  {**
   * @desc 高精度秒表，基于单调时钟
   *}
  TStopwatch = record
  private
    FStarted: Boolean;
    FRunning: Boolean;
    FStart: TInstant;
    FAccumulated: TDuration;
  public
    class function Create: TStopwatch; static;
    class function StartNew: TStopwatch; static;

    procedure Start;
    procedure Stop;
    procedure Reset;
    procedure Restart;

    function Elapsed: TDuration;
    function ElapsedMilliseconds: Int64; inline;
    function IsRunning: Boolean; inline;
  end;

implementation

{ TStopwatch }

class function TStopwatch.Create: TStopwatch;
begin
  Result.FStarted := False;
  Result.FRunning := False;
  Result.FAccumulated := TDuration.Zero;
end;

class function TStopwatch.StartNew: TStopwatch;
begin
  Result := TStopwatch.Create;
  Result.Start;
end;

procedure TStopwatch.Start;
begin
  if not FRunning then
  begin
    FStart := TInstant.Now;
    FRunning := True;
    FStarted := True;
  end;
end;

procedure TStopwatch.Stop;
begin
  if FRunning then
  begin
    FAccumulated := FAccumulated + TInstant.Now.DurationSince(FStart);
    FRunning := False;
  end;
end;

procedure TStopwatch.Reset;
begin
  FRunning := False;
  FStarted := False;
  FAccumulated := TDuration.Zero;
end;

procedure TStopwatch.Restart;
begin
  FAccumulated := TDuration.Zero;
  FStart := TInstant.Now;
  FRunning := True;
  FStarted := True;
end;

function TStopwatch.Elapsed: TDuration;
begin
  if FRunning then
    Result := FAccumulated + TInstant.Now.DurationSince(FStart)
  else
    Result := FAccumulated;
end;

function TStopwatch.ElapsedMilliseconds: Int64;
begin
  Result := Elapsed.AsMilliseconds;
end;

function TStopwatch.IsRunning: Boolean;
begin
  Result := FRunning;
end;

end.
