program Record_methods_pass;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

type
  TVector2 = record
    X: Double;
    Y: Double;
    class function Create(AX, AY: Double): TVector2; static;
    function Length: Double;
    function Normalized: TVector2;
  end;

class function TVector2.Create(AX, AY: Double): TVector2;
begin
  Result.X := AX;
  Result.Y := AY;
end;

function TVector2.Length: Double;
begin
  Result := Sqrt(X * X + Y * Y);
end;

function TVector2.Normalized: TVector2;
var
  Len: Double;
begin
  Len := Length;
  if Len > 0 then
  begin
    Result.X := X / Len;
    Result.Y := Y / Len;
  end
  else
  begin
    Result.X := 0;
    Result.Y := 0;
  end;
end;

var
  V: TVector2;
  Len: Double;
begin
  V := TVector2.Create(3.0, 4.0);
  Len := V.Length;
  V := V.Normalized;
end.
