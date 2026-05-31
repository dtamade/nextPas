unit nextpas.core.time.deadline;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base;

type
  TDeadlineKind = (dkFinite, dkInfinite);

  TDeadline = record
  private
    FKind: TDeadlineKind;
    FAt: TInstant;
  public
    class function At(const AInstant: TInstant): TDeadline; static;
    class function After(const ATimeout: TDuration): TDeadline; static;
    class function Infinite: TDeadline; static;
    class function Expired: TDeadline; static;

    function IsInfinite: Boolean; inline;
    function IsExpired: Boolean; inline;
    function TimeUntil: TDuration;
    function Remaining: TDuration;
    function ToInstant(out AInstant: TInstant): Boolean;
    class function Min(const A, B: TDeadline): TDeadline; static;

    class operator =(const A, B: TDeadline): Boolean;
  end;

implementation

{ TDeadline }

class function TDeadline.At(const AInstant: TInstant): TDeadline;
begin
  Result.FKind := dkFinite;
  Result.FAt := AInstant;
end;

class function TDeadline.After(const ATimeout: TDuration): TDeadline;
begin
  if ATimeout.AsNanoseconds <= 0 then
  begin
    Result := TDeadline.Expired;
    Exit;
  end;
  Result.FKind := dkFinite;
  Result.FAt := TInstant.Now.Add(ATimeout);
end;

class function TDeadline.Infinite: TDeadline;
begin
  Result.FKind := dkInfinite;
  Result.FAt := Default(TInstant);
end;

class function TDeadline.Expired: TDeadline;
begin
  Result.FKind := dkFinite;
  Result.FAt := Default(TInstant); { FNs = 0, always in the past }
end;

function TDeadline.IsInfinite: Boolean;
begin
  Result := FKind = dkInfinite;
end;

function TDeadline.IsExpired: Boolean;
var
  LNow: TInstant;
begin
  if FKind = dkInfinite then
    Exit(False);
  LNow := TInstant.Now;
  Result := (LNow = FAt) or (LNow > FAt);
end;

function TDeadline.TimeUntil: TDuration;
var
  LNow: TInstant;
begin
  if FKind = dkInfinite then
    Exit(TDuration.MaxValue);
  LNow := TInstant.Now;
  Result := FAt.DurationSince(LNow);
end;

function TDeadline.Remaining: TDuration;
var
  LDur: TDuration;
begin
  if FKind = dkInfinite then
    Exit(TDuration.MaxValue);
  LDur := TimeUntil;
  if LDur.AsNanoseconds <= 0 then
    Result := TDuration.Zero
  else
    Result := LDur;
end;

function TDeadline.ToInstant(out AInstant: TInstant): Boolean;
begin
  if FKind = dkInfinite then
  begin
    AInstant := Default(TInstant);
    Result := False;
  end
  else
  begin
    AInstant := FAt;
    Result := True;
  end;
end;

class function TDeadline.Min(const A, B: TDeadline): TDeadline;
begin
  if A.FKind = dkInfinite then
    Exit(B);
  if B.FKind = dkInfinite then
    Exit(A);
  if A.FAt < B.FAt then
    Result := A
  else
    Result := B;
end;

class operator TDeadline.=(const A, B: TDeadline): Boolean;
begin
  if A.FKind <> B.FKind then
    Exit(False);
  if A.FKind = dkInfinite then
    Exit(True);
  Result := A.FAt = B.FAt;
end;

end.
